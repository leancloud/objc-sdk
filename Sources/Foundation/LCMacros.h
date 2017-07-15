//
//  LCMacros.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 16/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#define _LC_NUM_ARGS(...) _LC_NUM_ARGS_OFFSET(_, ## __VA_ARGS__, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0)
#define _LC_NUM_ARGS_OFFSET(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, N, ...) N

#define _LC_MACRO_DISPATCH(prefix, ...) _LC_MACRO_DISPATCH_(prefix, _LC_NUM_ARGS(__VA_ARGS__))
#define _LC_MACRO_DISPATCH_(prefix, argc) _LC_MACRO_DISPATCH__(prefix, argc)
#define _LC_MACRO_DISPATCH__(prefix, argc) prefix ## argc
