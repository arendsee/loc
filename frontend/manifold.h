#ifndef __MANIFOLD_H__
#define __MANIFOLD_H__

#include <stdlib.h>
#include <string.h>

typedef struct Manifold {
    int uid;
    char* function;
    struct Ws* effect; // Couplet<char*>
    struct Ws* cache;  // Couplet<char*>
    struct Ws* check;  // "
    struct Ws* open;   // "
    struct Ws* pack;   // "
    struct Ws* pass;   // "
    struct Ws* fail;   // "
    struct Ws* doc;    // "
    struct Ws* inputs; // Couplet<Manifold*>
    struct Ws* args;   // Couplet<P_STRING,Ws<P_STRING>>
} Manifold;

Manifold* manifold_new();

// Creates a copy of m with a new uid
Manifold* manifold_clone(Manifold* m);

#endif