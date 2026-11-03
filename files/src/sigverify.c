/* SPDX-License-Identifier: GPL-3.0-or-later
 * sigverify PUBKEY SIGFILE FILE: check a signify (OpenBSD) Ed25519 signature.
 * Same file formats as `signify -V`; uses LibreSSL's Ed25519, nothing else. */
#include <stddef.h>
#include <stdint.h>
#include <openssl/curve25519.h>
#include <openssl/evp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int blob(const char *path, unsigned char *out, size_t want) {
	char l1[1024], l2[1024]; unsigned char b[256]; int n;
	FILE *f = fopen(path, "r");
	if (!f || !fgets(l1, sizeof l1, f) || strncmp(l1, "untrusted comment: ", 19) || !fgets(l2, sizeof l2, f)) return -1;
	fclose(f);
	l2[strcspn(l2, "\r\n")] = 0;
	n = EVP_DecodeBlock(b, (unsigned char *)l2, strlen(l2));
	if (n < 0) return -1;
	n -= (l2[strlen(l2) - 1] == '=') + (l2[strlen(l2) - 2] == '=');
	if ((size_t)n != want || b[0] != 'E' || b[1] != 'd') return -1;
	memcpy(out, b, want);
	return 0;
}

int main(int c, char **v) {
	unsigned char pk[42], sig[74], *m = NULL; size_t len = 0, cap = 0, r; FILE *f;
	if (c != 4) { fprintf(stderr, "usage: sigverify PUBKEY SIGFILE FILE\n"); return 2; }
	if (blob(v[1], pk, sizeof pk)) { fprintf(stderr, "sigverify: bad public key %s\n", v[1]); return 1; }
	if (blob(v[2], sig, sizeof sig)) { fprintf(stderr, "sigverify: bad signature %s\n", v[2]); return 1; }
	if (memcmp(pk + 2, sig + 2, 8)) { fprintf(stderr, "sigverify: signed by a different key\n"); return 1; }
	if (!(f = fopen(v[3], "rb"))) { perror(v[3]); return 1; }
	do { if (len == cap && !(m = realloc(m, cap = cap ? cap * 2 : 1 << 20))) return 1; }
	while ((r = fread(m + len, 1, cap - len, f)) && (len += r));
	fclose(f);
	if (!ED25519_verify(m, len, sig + 10, pk + 10)) { fprintf(stderr, "sigverify: BAD signature\n"); return 1; }
	puts("Signature Verified");
	return 0;
}
