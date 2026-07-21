/*
 * Fuzz target: CLIgen user-input pipeline.
 *
 * A fixed, complex CLIgen spec is built once in LLVMFuzzerInitialize(). Each
 * fuzzer input is treated as a line of user input and driven through the full
 * interactive pipeline:
 *
 *   1. cligen_str2cvv()      – tokenise (next_token, quote/escape/pipe)
 *   2. match_pattern()       – prefix match (tab/help path, best=0)
 *   3. match_complete()      – try to extend the partial token
 *   4. match_pattern_exact() – exact match (execute path)
 *
 * This exercises code paths that fuzz_match.c does not reach:
 *   - Named sub-trees and @-references
 *   - Pipe trees and the '|' separator
 *   - Set syntax (@{})
 *   - Optional groups ([])
 *   - decimal64, uuid, url, time variable types
 *   - match_complete / match_complete_mr string-completion logic
 *
 * Build: see build.sh (add fuzz_input to TARGETS).
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <cligen/cligen.h>
#include <cligen/cligen_match.h>

static cligen_handle gh;

/*
 * A spec that is deliberately wide and deep so many grammar and matcher code
 * paths are reachable from short fuzzer inputs.
 *
 * It includes:
 *   - named trees (subtree, pipetree) and @-references
 *   - pipe tree ("| <treename>") to exercise pipe handling
 *   - @{} sets for unordered multi-keyword commands
 *   - [] optionals at multiple nesting levels
 *   - variables of every supported base type
 *   - regexp, range, choice, length constraints
 *   - expand placeholder (no real callback — the expand will return 0 matches,
 *     but the code path in the matcher is still exercised)
 *   - decimal64 with fraction-digits
 *   - nested sub-tree reference via @subtree
 */
static const char *spec =
    /* ---- named subtree used via @subtree reference ---- */
    "treename=\"subtree\";\n"
    "  read  [verbose] <file:string length[1:64]>;\n"
    "  write [force]   <file:string length[1:64]> [offset <off:uint64>];\n"
    "  stat;\n"

    /* ---- pipe tree: filters available after '|' ---- */
    "treename=\"|pipetree\";\n"
    "  grep  <pattern:string>;\n"
    "  count;\n"
    "  head  [<n:uint32 range[1:1000]>];\n"
    "  tail  [<n:uint32 range[1:1000]>];\n"

    /* ---- main tree ---- */
    "treename=\"main\";\n"
    "prompt=\"fuzz> \";\n"
    "comment=\"#\";\n"

    /* plain commands */
    "quit;\n"
    "help;\n"

    /* set with subtree reference */
    "file @subtree;\n"

    /* show with many sub-commands */
    "show {\n"
    "  version;\n"
    "  interfaces [detail];\n"
    "  interface <ifname:string regexp:\"[a-zA-Z][a-zA-Z0-9]*[0-9]+\"> [statistics];\n"
    "  route <dst:ipv4prefix> [nexthop <nh:ipv4addr>];\n"
    "  route6 <dst:ipv6prefix> [nexthop <nh:ipv6addr>];\n"
    "  mac <m:macaddr>;\n"
    "  time <t:time>;\n"
    "  uuid <u:uuid>;\n"
    "  decimal <d:decimal64 fraction-digits:3>;\n"
    "  url <u:url>;\n"
    "  (history|log) [<lines:uint16 range[1:9999]>];\n"
    "}\n"

    /* set with @{} unordered multi-keyword */
    "config @{\n"
    "  hostname <name:string length[1:64]>;\n"
    "  mtu <mtu:uint16 range[68:9000]>;\n"
    "  debug (on|off);\n"
    "  log level <lvl:string choice:emerg|alert|crit|err|warning|notice|info|debug>;\n"
    "}\n"

    /* ping with optional count and size, pipe to pipetree */
    "ping <host:ipv4addr> [count <c:uint32 range[1:65535]>] [size <s:uint32 range[0:65507]>];\n"
    "ping6 <host:ipv6addr>;\n"

    /* traceroute */
    "traceroute <dest:ipv4addr> [ttl <ttl:uint8 range[1:255]>];\n"

    /* integer range stress */
    "test int8  <v:int8  range[-128:-1] range[1:127]>;\n"
    "test int16 <v:int16>;\n"
    "test int32 <v:int32 range[-2147483648:2147483647]>;\n"
    "test int64 <v:int64>;\n"
    "test uint8  <v:uint8>;\n"
    "test uint32 <v:uint32>;\n"
    "test uint64 <v:uint64>;\n"
    "test bool <v:bool>;\n"
    "test str  <v:string regexp:\"[^\\t]+\">;\n"
    "test rest <v:rest>;\n"

    /* nested optionals */
    "load [startup] [file <f:string>] [validate];\n"
    "save [file <f:string>] [compress];\n"
    ;

int
LLVMFuzzerInitialize(int *argc, char ***argv)
{
    cvec *globals;

    (void)argc;
    (void)argv;
    if ((gh = cligen_init()) == NULL)
        abort();
    if ((globals = cvec_new(0)) == NULL)
        abort();
    /* Parse into the handle; tree named "main" becomes active. */
    if (clispec_parse_str(gh, spec, "main", NULL, NULL, globals) < 0)
        abort();
    cvec_free(globals);
    /* Activate the main tree. */
    if (cligen_ph_active_set_byname(gh, "main") < 0)
        abort();
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char          *s      = NULL;
    cvec          *cvt    = NULL;
    cvec          *cvr    = NULL;
    cvec          *cvv    = NULL;
    match_result  *mr     = NULL;
    cg_obj        *match_obj = NULL;
    cligen_result  result;
    char          *reason = NULL;
    pt_head       *ph;
    parse_tree    *pt;
    char          *sbuf   = NULL;   /* copy of s for match_complete (may realloc) */
    size_t         sbuflen = 0;

    if ((s = malloc(size + 1)) == NULL)
        return 0;
    memcpy(s, data, size);
    s[size] = '\0';

    /* Step 1: tokenise */
    if (cligen_str2cvv(s, &cvt, &cvr) < 0)
        goto done;

    ph = cligen_ph_active_get(gh);
    if (ph == NULL)
        goto done;
    pt = cligen_ph_parsetree_get(ph);
    if (pt == NULL)
        goto done;

    if ((cvv = cvec_new(0)) == NULL)
        goto done;

    /* Step 2: prefix match (tab/help path, best=0 → all candidates) */
    if (match_pattern(gh, cvt, cvr, pt,
                      0,    /* best=0: return all candidates */
                      cvv,
                      &mr) == 0 && mr != NULL) {
        mr_free(mr);
        mr = NULL;
    }

    /* Step 3: completion — match_complete needs an allocated input buffer that
     * it may realloc. Give it a fresh copy of the input string. */
    sbuflen = size + 64;
    if ((sbuf = malloc(sbuflen)) != NULL) {
        memcpy(sbuf, s, size + 1);
        (void)match_complete(gh, pt, &sbuf, &sbuflen, cvv);
        free(sbuf);
        sbuf = NULL;
    }

    /* Reset cvv for the exact-match call */
    cvec_free(cvv);
    if ((cvv = cvec_new(0)) == NULL)
        goto done;

    /* Step 4: exact match (execute path) */
    (void)match_pattern_exact(gh, cvt, cvr, pt, cvv,
                              &match_obj, &result, &reason);
    if (match_obj) {
        co_free(match_obj, 0);
        match_obj = NULL;
    }
    if (reason) {
        free(reason);
        reason = NULL;
    }

done:
    if (mr)
        mr_free(mr);
    if (cvv)
        cvec_free(cvv);
    if (cvt)
        cvec_free(cvt);
    if (cvr)
        cvec_free(cvr);
    free(s);
    return 0;
}
