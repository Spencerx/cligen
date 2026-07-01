/*
 * Fuzz target: CLIgen value (cv) type parsers.
 *
 * The first input byte selects a cv type; the remaining bytes are parsed as a
 * value of that type with cv_parse1(). This isolates the per-type string
 * parsers (ipv4/ipv6/mac/uuid/time/url/decimal/int/...).
 *
 * Build: see build.sh
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <cligen/cligen.h>

/* Types worth exercising (those with non-trivial string parsing). */
static const enum cv_type types[] = {
    CGV_INT8,  CGV_INT16,  CGV_INT32,  CGV_INT64,
    CGV_UINT8, CGV_UINT16, CGV_UINT32, CGV_UINT64,
    CGV_DEC64, CGV_BOOL,   CGV_STRING, CGV_REST,
    CGV_IPV4ADDR, CGV_IPV4PFX, CGV_IPV6ADDR, CGV_IPV6PFX,
    CGV_MACADDR,  CGV_URL,     CGV_UUID,      CGV_TIME,
};
static const size_t ntypes = sizeof(types) / sizeof(types[0]);

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    enum cv_type  type;
    cg_var       *cv;
    char         *s;
    char         *reason = NULL;

    if (size < 1)
        return 0;
    type = types[data[0] % ntypes];
    data++;
    size--;

    if ((s = malloc(size + 1)) == NULL)
        return 0;
    memcpy(s, data, size);
    s[size] = '\0';

    if ((cv = cv_new(type)) != NULL) {
        if (type == CGV_DEC64)
            cv_dec64_n_set(cv, 2);      /* parser requires fraction-digits set */
        (void)cv_parse1(s, cv, &reason);
        if (reason)
            free(reason);
        cv_free(cv);
    }
    free(s);
    return 0;
}
