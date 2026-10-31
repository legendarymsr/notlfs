/* tget: tiny HTTPS GET with certificate verification (LibreSSL libtls).
 * usage: tget [-t secs] URL   -> body on stdout; exit 1 on TLS/HTTP error.
 * CA bundle: $SSL_CERT_FILE or /etc/ssl/certs/ca-certificates.crt. HTTP/1.0, follows redirects. */
#include <tls.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <signal.h>

static int fail(const char *m, const char *d) { fprintf(stderr, "tget: %s%s%s\n", m, d ? ": " : "", d ? d : ""); return 1; }

static int get(const char *url, int depth) {
	char host[256], port[8] = "443", path[4096], req[4600];
	if (strncmp(url, "https://", 8)) return fail("only https:// URLs", url);
	const char *h = url + 8, *p = strchr(h, '/');
	size_t hl = p ? (size_t)(p - h) : strlen(h);
	if (hl >= sizeof host) return fail("host too long", NULL);
	memcpy(host, h, hl); host[hl] = 0;
	snprintf(path, sizeof path, "%s", p ? p : "/");
	char *c = strchr(host, ':'); if (c) { *c = 0; snprintf(port, sizeof port, "%s", c + 1); }
	struct tls_config *cfg = tls_config_new();
	const char *ca = getenv("SSL_CERT_FILE"); if (!ca) ca = "/etc/ssl/certs/ca-certificates.crt";
	if (tls_config_set_ca_file(cfg, ca) < 0) return fail("CA bundle", tls_config_error(cfg));
	struct tls *t = tls_client();
	if (tls_configure(t, cfg) < 0 || tls_connect(t, host, port) < 0 || tls_handshake(t) < 0)
		return fail(host, tls_error(t));
	int n = snprintf(req, sizeof req, "GET %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: tget/1\r\nAccept: */*\r\nConnection: close\r\n\r\n", path, host);
	for (int o = 0; o < n;) { ssize_t w = tls_write(t, req + o, n - o); if (w == TLS_WANT_POLLIN || w == TLS_WANT_POLLOUT) continue; if (w < 0) return fail("write", tls_error(t)); o += w; }
	char *hd = malloc(65536); size_t hn = 0; char *body = NULL;
	while (!body) {
		if (hn >= 65535) return fail("headers too large", NULL);
		ssize_t r = tls_read(t, hd + hn, 65535 - hn);
		if (r == TLS_WANT_POLLIN || r == TLS_WANT_POLLOUT) continue;
		if (r <= 0) return fail("connection closed in headers", r < 0 ? tls_error(t) : NULL);
		hn += r; hd[hn] = 0; body = strstr(hd, "\r\n\r\n");
	}
	*body = 0; body += 4;
	int st = atoi(strchr(hd, ' ') ? strchr(hd, ' ') + 1 : "0");
	if (st >= 300 && st < 400 && depth < 5) {
		for (char *l = strstr(hd, "\r\n"); l; l = strstr(l + 2, "\r\n"))
			if (!strncasecmp(l + 2, "location:", 9)) {
				char *v = l + 11; while (*v == ' ') v++;
				char *e = strstr(v, "\r\n"); if (e) *e = 0;
				char nu[4400];
				if (*v == '/') snprintf(nu, sizeof nu, "https://%s%s", host, v); else snprintf(nu, sizeof nu, "%s", v);
				tls_close(t); return get(nu, depth + 1);
			}
	}
	if (st != 200) return fail("HTTP status", strchr(hd, ' ') ? strchr(hd, ' ') + 1 : hd);
	fwrite(body, 1, hd + hn - body, stdout);
	char buf[16384];
	for (;;) { ssize_t r = tls_read(t, buf, sizeof buf);
		if (r == TLS_WANT_POLLIN || r == TLS_WANT_POLLOUT) continue;
		if (r <= 0) break; fwrite(buf, 1, r, stdout); }
	tls_close(t); return 0;
}

int main(int argc, char **argv) {
	int to = 15;
	if (argc > 2 && !strcmp(argv[1], "-t")) { to = atoi(argv[2]); argv += 2; argc -= 2; }
	if (argc != 2) { fputs("usage: tget [-t secs] https://URL\n", stderr); return 2; }
	signal(SIGALRM, SIG_DFL); alarm(to);
	return get(argv[1], 0);
}
