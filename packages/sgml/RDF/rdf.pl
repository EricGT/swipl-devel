/*  $Id$

    Part of SWI-Prolog RDF parser

    Author:  Jan Wielemaker
    E-mail:  jan@swi.psy.uva.nl
    WWW:     http://www.swi.psy.uva.nl/projects/SWI-Prolog/
    Copying: LGPL-2.  See the file COPYING or http://www.gnu.org

    Copyright (C) 1990-2000 SWI, University of Amsterdam. All rights reserved.
*/

:- module(rdf,
	  [ load_rdf/2,			% +File, -Triples
	    load_rdf/3,			% +File, -Triples, +Options
	    xml_to_rdf/3,		% +XML, +BaseURI, -Triples
	    process_rdf/3		% +File, +BaseURI, :OnTriples
	  ]).

:- meta_predicate(process_rdf(+, :, +)).

:- use_module(library(sgml)).		% Basic XML loading
:- use_module(rdf_parser).		% Basic parser
:- use_module(rdf_triple).		% Generate triples

%	load_rdf(+File, -Triples[, +Options])
%
%	Parse an XML file holding an RDF term into a list of RDF triples.
%	see rdf_triple.pl for a definition of the output format. Options:
%
%	# base_uri(URI)
%	URI to use as base
%
%	# expand_foreach(Bool)
%	Apply each(Container, Pred, Object) on the members of Container

load_rdf(File, Triples) :-
	load_rdf(File, Triples, []).

load_rdf(File, Triples, Options) :-
	option(base_uri(BaseURI), Options, []),
	load_structure(File,
		       [ RDFElement
		       ],
		       [ dialect(xmlns),
			 space(sgml)
		       ]),
	set_anon_prefix(BaseURI, Refs),
	rdf_start_file(Options),
	call_cleanup(xml_to_rdf(RDFElement, Triples0, Options),
		     cleanup_load(Refs)),
	post_process(Options, Triples0, Triples).
	
%	xml_to_rdf(+XML, -Triples, +Options)

xml_to_rdf(XML, Triples, Options) :-
	is_list(Options), !,
	xml_to_plrdf(XML, RDF, Options),
	rdf_triples(RDF, Triples).
xml_to_rdf(XML, BaseURI, Triples) :-
	atom(BaseURI), !,
	xml_to_rdf(XML, Triples, [base_uri(BaseURI)]).


set_anon_prefix([], []) :- !.
set_anon_prefix(BaseURI, [Ref]) :-
	concat_atom(['__', BaseURI, '#'], AnonBase),
	asserta(anon_prefix(AnonBase), Ref).

cleanup_load(Refs) :-
	rdf_end_file,
	erase_refs(Refs).

erase_refs([]).
erase_refs([H|T]) :-
	erase(H),
	erase_refs(T).


		 /*******************************
		 *	 POST-PROCESSING	*
		 *******************************/

post_process([], Triples, Triples).
post_process([expand_foreach(true)|T], Triples0, Triples) :- !,
	expand_each(Triples0, Triples1),
	post_process(T, Triples1, Triples).
post_process([_|T], Triples0, Triples) :- !,
	post_process(T, Triples0, Triples).


		 /*******************************
		 *	      EXPAND		*
		 *******************************/

expand_each(Triples0, Triples) :-
	select(rdf(each(Container), Pred, Object),
	       Triples0, Triples1), !,
	each_triples(Triples1, Container, Pred, Object, Triples2),
	expand_each(Triples2, Triples).
expand_each(Triples, Triples).

each_triples([], _, _, _, []).
each_triples([H0|T0], Container, P, O,
	     [H0, rdf(S,P,O)|T]) :-
	H0 = rdf(Container, rdf:A, S),
	member_attribute(A), !,
	each_triples(T0, Container, P, O, T).
each_triples([H|T0], Container, P, O, [H|T]) :-
	each_triples(T0, Container, P, O, T).

member_attribute(A) :-
	sub_atom(A, 0, _, _, '_').	% must check number?


		 /*******************************
		 *	     BIG FILES		*
		 *******************************/

%	process_rdf(+Input, :OnObject, +Options)
%	
%	Process RDF from Input. Input is either an atom or a term of the
%	format stream(Handle). For each   encountered  description, call
%	OnObject(+Triples) to handle the  triples   resulting  from  the
%	description. Defined Options are:
%	
%		# base_uri(+URI)
%		Determines the reference URI.

process_rdf(File, OnObject, Options) :-
	is_list(Options), !,
	option(base_uri(BaseURI), Options, []),
	rdf_start_file(Options),
	'$strip_module'(OnObject, Module, Pred),
	nb_setval(rdf_object_handler, Module:Pred),
	nb_setval(rdf_options, Options),
	nb_setval(rdf_state, -),
	(   File = stream(In)
	->  Source = BaseURI
	;   File = '$stream'(_)
	->  In = File,
	    Source = BaseURI
	;   open(File, read, In, [type(binary)]),
	    Close = In,
	    Source = File
	),
	new_sgml_parser(Parser, []),
	set_sgml_parser(Parser, file(Source)),
	set_sgml_parser(Parser, dialect(xmlns)),
	set_sgml_parser(Parser, space(sgml)),
	set_anon_prefix(BaseURI, Refs),
	call_cleanup(sgml_parse(Parser,
				[ source(In),
				  call(begin, rdf:on_begin),
				  call(end, rdf:on_end)
				]),
		     rdf:cleanup_process(Close, Refs)).
process_rdf(File, BaseURI, OnObject) :-
%	print_message(warning,
%		      format('process_rdf(): new argument order', [])),
	process_rdf(File, OnObject, [base_uri(BaseURI)]).


cleanup_process(In, Refs) :-
	(   var(In)
	->  true
	;   close(In)
	),
	nb_delete(rdf_options),
	nb_delete(rdf_object_handler),
	nb_delete(rdf_state),
	erase_refs(Refs),
	rdf_end_file.

on_end(NS:'RDF', _) :-
	rdf_name_space(NS),
	nb_setval(rdf_description_options, -).

on_begin(NS:'RDF', Attr, _) :-
	rdf_name_space(NS), !,
	nb_getval(rdf_options, Options0),
	modify_state(Attr, Options0, Options),
	nb_setval(rdf_state, Options).
on_begin(Tag, Attr, Parser) :-
	nb_getval(rdf_state, Options),
	Options \== (-), !,
	get_sgml_parser(Parser, line(Start)),
	get_sgml_parser(Parser, file(File)),
	sgml_parse(Parser,
		   [ document(Content),
		     parse(content)
		   ]),
	nb_getval(rdf_object_handler, OnTriples),
	element_to_plrdf(element(Tag, Attr, Content), Objects, Options),
	rdf_triples(Objects, Triples),
	call(OnTriples, Triples, File:Start).


modify_state([], Options, Options).
modify_state([H|T], Options0, Options) :-
	modify_state1(H, Options0, Options1),
	modify_state(T, Options1, Options).

modify_state1(xml:base = Base, Options0, Options) :- !,
	set_option(base_uri(Base), Options0, Options).
modify_state1(xml:lang = Lang, Options0, Options) :- !,
	set_option(lang(Lang), Options0, Options).
modify_state1(_, Options, Options).

set_option(Opt, Options0, [Opt|Options]) :-
	functor(Opt, F, A),
	functor(VO, F, A),
	delete(Options0, VO, Options).


		 /*******************************
		 *	      UTIL		*
		 *******************************/

%	option(Option(?Value), OptionList, Default)

option(Opt, Options) :-
	memberchk(Opt, Options), !.
option(Opt, Options) :-
	functor(Opt, OptName, 1),
	arg(1, Opt, OptVal),
	memberchk(OptName=OptVal, Options), !.

option(Opt, Options, _) :-
	option(Opt, Options), !.
option(Opt, _, Default) :-
	arg(1, Opt, Default).


		 /*******************************
		 *	      MESSAGES		*
		 *******************************/

:- multifile
	prolog:message/3.

%	Catch messages.  sgml/4 is generated by the SGML2PL binding.

prolog:message(rdf(unparsed(Data))) -->
	{ phrase(unparse_xml(Data), XML)
	},
	[ 'RDF: Failed to interpret "~s"'-[XML] ].
prolog:message(rdf(protege(id, Id))) -->
	[ 'RDF: Fixed Protege 1.3 ID="~w" bug'-[Id] ].
prolog:message(rdf(shared_blank_nodes(N))) -->
	[ 'RDF: Shared ~D blank nodes'-[N] ].
prolog:message(rdf(not_a_name(Name))) -->
	[ 'RDF: argument to rdf:ID is not an XML name: ~p'-[Name] ].
prolog:message(rdf(redefined_id(Id))) -->
	[ 'RDF: rdf:ID ~p: multiple definitions'-[Id] ].


		 /*******************************
		 *	    XML-TO-TEXT		*
		 *******************************/

unparse_xml([]) --> !,
	[].
unparse_xml([H|T]) --> !,
	unparse_xml(H),
	unparse_xml(T).
unparse_xml(Atom) -->
	{ atom(Atom)
	}, !,
	atom(Atom).
unparse_xml(element(Name, Attr, Content)) -->
	"<",
	identifier(Name),
	attributes(Attr),
	(   { Content == []
	    }
	->  "/>"
	;   ">",
	    unparse_xml(Content)
	).
	
attributes([]) -->
	[].
attributes([H|T]) -->
	attribute(H),
	attributes(T).

attribute(Name=Value) -->
	" ",
	identifier(Name),
	"=",
	value(Value).

identifier(NS:Local) --> !,
	"{", atom(NS), "}",
	atom(Local).
identifier(Local) -->
	atom(Local).

atom(Atom, Text, Rest) :-
	atom_codes(Atom, Chars),
	append(Chars, Rest, Text).

value(Value) -->
	{ atom_codes(Value, Chars)
	},
	"\"",
	quoted(Chars),
	"\"".

quoted([]) -->
	[].
quoted([H|T]) -->
	quote(H), !,
	quoted(T).

quote(0'<) --> "&lt;".
quote(0'>) --> "&gt;".
quote(0'") --> "&quot;".
quote(0'&) --> "&amp;".
quote(X)   --> [X].
