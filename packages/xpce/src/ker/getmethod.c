/*  $Id$

    Part of XPCE

    Author:  Jan Wielemaker and Anjo Anjewierden
    E-mail:  jan@swi.psy.uva.nl
    WWW:     http://www.swi.psy.uva.nl/projects/xpce/
    Copying: GPL-2.  See the file COPYING or http://www.gnu.org

    Copyright (C) 1990-2001 SWI, University of Amsterdam. All rights reserved.
*/

#define INLINE_UTILITIES 1
#include <h/kernel.h>


GetMethod
createGetMethod(Name name, Type rtype, Vector types,
		StringObj doc, Func action)
{ GetMethod m = alloc(sizeof(struct get_method));

  initHeaderObj(m, ClassGetMethod);
  m->return_type = (Type) NIL;
  assign(m, return_type, rtype);
  createMethod((Method) m, name, types, doc, action);

  return m;
}


status
initialiseGetMethod(GetMethod m, Name name, Type rtype,
		    Vector types, Function msg,
		    StringObj doc, SourceLocation loc, Name group)
{ if ( isDefault(rtype) )
    rtype = TypeUnchecked;

  TRY(initialiseMethod((Method) m, name, types, (Code) msg, doc, loc, group));
  assign(m, return_type, rtype);

  succeed;
}


		 /*******************************
		 *	 CLASS DECLARATION	*
		 *******************************/

/* Type declaractions */

static char *T_initialise[] =
        { "name=name", "return=[type]", "types=[vector]",
	  "implementation=function|c_pointer",
	  "summary=[string]*",
	  "source=[source_location]*", "group=[name]*" };
static char *T_get[] =
        { "receiver=object", "argument=unchecked ..." };

/* Instance Variables */

static vardecl var_getMethod[] =
{ IV(NAME_returnType, "type", IV_GET,
     NAME_type, "Type of value returned")
};

/* Send Methods */

static senddecl send_getMethod[] =
{ SM(NAME_initialise, 7, T_initialise, initialiseGetMethod,
     DEFAULT, "->selector, return_type, types, msg, doc, location")
};

/* Get Methods */

static getdecl get_getMethod[] =
{ GM(NAME_get, 2, "value=unchecked", T_get, getGetGetMethod,
     NAME_execute, "Invoke get-method")
};

/* Resources */

#define rc_getMethod NULL
/*
static classvardecl rc_getMethod[] =
{ 
};
*/

/* Class Declaration */

static Name getMethod_termnames[] = { NAME_name, NAME_returnType, NAME_types,
				      NAME_summary
				    };

ClassDecl(getMethod_decls,
          var_getMethod, send_getMethod, get_getMethod, rc_getMethod,
          4, getMethod_termnames,
          "$Rev$");


status
makeClassGetMethod(Class class)
{ return declareClass(class, &getMethod_decls);
}
