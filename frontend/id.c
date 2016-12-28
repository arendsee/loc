#include "id.h"

Id* id_new(){
    static int uid = 0;
    Id* i = (Id*)calloc(1, sizeof(Id));
    i->uid = uid++;
    return i;
}

Id* id_clone(Id* id){

    if(!id) return NULL;

    Id* newid = id_new();
    newid->name = id->name ? strdup(id->name) : NULL;
    newid->label = id->label ? strdup(id->label) : NULL;

    return newid;
}

Id* id_from_str(char* s){
    Id* id = id_new();
    int i = 0;
    for(;;i++){
        if(s[i] == '\0'){
            break;
        }
        else if(s[i] == ':'){
            id->label = strdup(s + i + 1);
            break;
        }
    }
    id->name = (char*)malloc((i+1) * sizeof(char));
    id->name = memcpy(id->name, s, i*sizeof(char));
    id->name[i] = '\0';

    id->name = trim_ws(id->name);
    id->label = trim_ws(id->label);

    return id;
}

bool id_cmp(Id* a, Id* b){
    if(!a || !b){
        fprintf(stderr, "WARNING: cannot compare null ids\n"); fflush(stderr);
    }
    if(!a->name || !b->name){
        fprintf(stderr, "WARNING: cannot compare nameless ids\n"); fflush(stderr);
    }
    bool result = 
        strcmp(a->name, b->name) == 0 &&
        (
            (a->label == NULL && b->label == NULL) ||
            (
                (a->label != NULL && b->label != NULL) &&
                strcmp(a->label, b->label) == 0
            )
        );
    return result;
}
