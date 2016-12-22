#include "ril.h"

RatStack* new_RatStack(){
     RatStack* rs = (RatStack*)calloc(1,sizeof(RatStack));
     rs->export = new_NamedList();
     rs->doc    = new_NamedList();
     rs->alias  = new_NamedList();
     rs->cache  = new_NamedList();
     rs->pack   = new_NamedList();
     rs->open   = new_NamedList();
     rs->fail   = new_NamedList();
     rs->pass   = new_NamedList();
     rs->source = new_NamedList();

     rs->ontology = new_NamedList();
     rs->type     = new_NamedList();

     rs->path   = new_NamedList();
     rs->check  = new_NamedList();
     rs->effect = new_NamedList();

     return rs;
}

void rewind_RatStack(RatStack* rs){
    REWIND( rs->export   );
    REWIND( rs->doc      );
    REWIND( rs->alias    );
    REWIND( rs->cache    );
    REWIND( rs->pack     );
    REWIND( rs->open     );
    REWIND( rs->fail     );
    REWIND( rs->pass     );
    REWIND( rs->source   );
    REWIND( rs->ontology );
    REWIND( rs->type     );
    REWIND( rs->path     );
    REWIND( rs->check    );
    REWIND( rs->effect   );
}

void print_couplet(NamedList* l, char* cmd){
    for( ; l; l = l->next ){
        printf("%s %s %s\n", cmd, l->name, l->value);
    }
}

void print_RIL(RatStack* rs){

    rewind_RatStack(rs);

    print_couplet(rs->export,   "EXPORT");
    print_couplet(rs->doc,      "DOC");
    print_couplet(rs->alias,    "ALIAS");
    print_couplet(rs->cache,    "CACHE");
    print_couplet(rs->pack,     "PACK");
    print_couplet(rs->open,     "OPEN");
    print_couplet(rs->fail,     "FAIL");
    print_couplet(rs->pass,     "PASS");
    print_couplet(rs->source,   "SOURCE");
    print_couplet(rs->ontology, "ONTOLOGY");
    print_couplet(rs->type,     "TYPE");

    for(NamedList* l = rs->path; l; l = l->next){
        printf("PATH %s\n", l->name);
    }
    for(NamedList* l = rs->check; l; l = l->next){
        printf("CHECK %s\n", l->name);
    }
    for(NamedList* l = rs->effect; l; l = l->next){
        printf("EFFECT %s\n", l->name);
    }
}
