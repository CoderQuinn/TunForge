//
//  TFWeakifyStrongify.h
//
//  Minimal @weakify / @strongify macros
//  Extracted and simplified from libextobjc
//
//  ARC-only, header-only, no runtime dependency
//

#ifndef TFWeakifyStrongify_h
#define TFWeakifyStrongify_h

#if !__has_feature(objc_arc)
#error TFWeakifyStrongify requires ARC
#endif

/* =========================
 * Helper macros
 * ========================= */

#define TF_METAMACRO_CAT(a, b) a##b
#define TF_METAMACRO_EXPAND(x) x

#define TF_METAMACRO_FOREACH_1(M, x) M(x)
#define TF_METAMACRO_FOREACH_2(M, x, ...) M(x) TF_METAMACRO_FOREACH_1(M, __VA_ARGS__)
#define TF_METAMACRO_FOREACH_3(M, x, ...) M(x) TF_METAMACRO_FOREACH_2(M, __VA_ARGS__)
#define TF_METAMACRO_FOREACH_4(M, x, ...) M(x) TF_METAMACRO_FOREACH_3(M, __VA_ARGS__)
#define TF_METAMACRO_FOREACH_5(M, x, ...) M(x) TF_METAMACRO_FOREACH_4(M, __VA_ARGS__)

#define TF_METAMACRO_GET_FOREACH(_1, _2, _3, _4, _5, NAME, ...) NAME
#define TF_METAMACRO_FOREACH(M, ...)                                                               \
    TF_METAMACRO_EXPAND(TF_METAMACRO_GET_FOREACH(__VA_ARGS__,                                      \
                                                 TF_METAMACRO_FOREACH_5,                           \
                                                 TF_METAMACRO_FOREACH_4,                           \
                                                 TF_METAMACRO_FOREACH_3,                           \
                                                 TF_METAMACRO_FOREACH_2,                           \
                                                 TF_METAMACRO_FOREACH_1)(M, __VA_ARGS__))

/* =========================
 * weakify / strongify core
 * ========================= */

#define TF_WEAKIFY_VAR(var) __weak __typeof__(var) TF_METAMACRO_CAT(weak_, var) = (var);

#define TF_STRONGIFY_VAR(var) __strong __typeof__(var) var = TF_METAMACRO_CAT(weak_, var);

/* =========================
 * Public macros
 * ========================= */

#define weakify(...) TF_METAMACRO_FOREACH(TF_WEAKIFY_VAR, __VA_ARGS__)

#define strongify(...) TF_METAMACRO_FOREACH(TF_STRONGIFY_VAR, __VA_ARGS__)

#endif /* TFWeakifyStrongify_h */
