:-encoding(utf8).
%% special concept that we could not manage to deal with the general evaluation framework
%%   we more or less follow the Python code, which explain the "ugliness" of this code

specialConcept('person',person).
specialConcept('government-organization',governmentOrganization).
specialConcept('have-degree-91',haveDegree91).
specialConcept('have-polarity-91',havePolarity91).
specialConcept('have-quant-91',haveQuant91).
specialConcept('have-purpose-91',havePurpose91).
specialConcept('have-rel-role-91',haveRelRole91).
specialConcept('date-entity',dateEntity).
specialConcept('ordinal-entity',ordinalEntity).
specialConcept(Name,quantity):-atom_concat(_,'-quantity',Name),!.
specialConcept(NE,namedEntity(NE)):-
    memberchk(NE,['continent','country','state','province','city','town',
                  'company','organization','university','publication']).

% hasRole(Roles,RoleCherché,StructDuRole,autresRoles)
% hasRole([],R,'not found',[]):-write('hasRole:'),write(R),write(' not found'),nl.
hasRole([[R,AMR]|Rs],R,AMR,Rs):-!.
hasRole([R1|Rs],R,A,[R1|RS0]):-hasRole(Rs,R,A,RS0).

% check if one of the roles is :ARGi or :OPi
hasArgOpRole([[R,_AMR]|_]):-isArgOp(R),!.
hasArgOpRole([_|Rs]):-hasArgOpRole(Rs).

changeNPD(S*Option,NewDet,S1*Option):-changeNPD(S,NewDet,S1).
changeNPD(NP,NewD,NP1):-
    NP=..[np,_D|Rest],NP1=..[np,NewD|Rest].

% build a list of evaluated values in an environment
buildSpecialEnv(_Roles,[],[]).
buildSpecialEnv(Roles,[RoleName|RNs],[RoleName:DSyntR|Env]):-
    hasRole(Roles,RoleName,AMR,Roles1),
    amr2dsr(AMR,_,_,DSyntR),
    buildSpecialEnv(Roles1,RNs,Env).
buildSpecialEnv(Roles,[_|RNs],Env):-
    buildSpecialEnv(Roles,RNs,Env).

%% deal with frequent patterns associated with a person
%%%% (p/person :ARG0-of (v / verb)) == ((p/person :*:ARG0 (v / verb :ARG0 p))) 
%%%%         ==> find verbalization
person(Roles,OutDSyntR):-
    hasRole(Roles,':*:ARG0',[Verb,_, [':ARG0',_]],Roles1), % should check the variable!!!
    verbalization('person',':*:ARG0',Verb,Verbalization),
    noun(Verbalization,DSyntR),
    %% add unprocessed roles
    buildRoleEnvOption(Verbalization,'Noun',Roles1,[],[],Env,Options),
    processRest(DSyntR,Env,Options,OutDSyntR).
%%% (p2 / person :ARG0-of (h / have-org-role-91 :ARG2 (m / mayor))) ==
%%%      [person,\p2,[':*:ARG0',['have-org-role-91',h,[':ARG0',p2], [':ARG2',[mayor,m]]] ==>
%%%  mayor !!!
person(Roles,OutDSyntR):-
    hasRole(Roles,':*:ARG0',
            ['have-org-role-91',_, 
                [':ARG0',_],[':ARG2',[Org_Role,_]]],Roles1), % should check the variable!!!
    noun(Org_Role,DSyntR),
    %% add unprocessed roles
    buildRoleEnvOption(Org_Role,'Noun',Roles1,[],[],Env,Options),
    processRest(DSyntR,Env,Options,OutDSyntR).
%%% (p / person
%%%          :ARG0-of (h / have-rel-role-91 :ARG1 (i / i):ARG2 (g / grandmother))) ==
%%%  [person,\p,[':*:ARG0',['have-rel-role-91',h, 
%%%                           [':ARG0',p], [':ARG1',[i,i]], [':ARG2',[grandmother,g]]]]]],  
person(Roles,OutDSyntR):-
    hasRole(Roles,':*:ARG0',
            ['have-rel-role-91',_, 
                [':ARG0',_],[':ARG1',Arg1],[':ARG2',[Org_Role,_]]],Roles1), % should check the variable!!!
    pronounOrPronounRef(Arg1,Poss),
    noun(Org_Role,DSyntR),
    applyEnv(DSyntR,['D':Poss],_,DSyntR1),
    %% add unprocessed roles
    buildRoleEnvOption(Org_Role,'Noun',Roles1,[],[],Env,Options),
    processRest(DSyntR1,Env,Options,OutDSyntR).
%%%% (p / person :name NAME  other roles)) replaced by  q(NAME) other roles
person(Roles,OutDSyntR):-namedEntity('person',Roles,OutDSyntR).
% person(Roles,OutDSyntR):-
%     hasRole(Roles,':name',AMR,Roles1),
%     amr2dsr(AMR,_Concept,_POS,DSyntR),
%     %% add unprocessed roles
%     buildRoleEnvOption('person','Special',Roles1,[],[],Env,Options),
%     processRest(DSyntR,Env,Options,OutDSyntR).
% % if no ":name" role, force person as a noun
% person(Roles,OutDSyntR):-
%     noun('person',ConceptDSyntR),
%     processConcept('Noun',['person',_Ivar|Roles],ConceptDSyntR,_ConceptOut,_POSOut,OutDSyntR).

%%%% (p / NamedEntity :name NAME  other roles)) replaced by  q(NAME) other roles
namedEntity(Entity,Roles,OutDSyntR):-
    hasRole(Roles,':name',AMR,Roles1),
    amr2dsr(AMR,_Concept,_POS,DSyntR),
    %% add unprocessed roles
    buildRoleEnvOption(Entity,'Special',Roles1,[],[],Env,Options),
    processRest(DSyntR,Env,Options,OutDSyntR).
% if no ":name" role, force Entity as a noun
namedEntity(Entity,Roles,OutDSyntR):-
    noun(Entity,ConceptDSyntR),
    processConcept('Noun',[Entity,_Ivar|Roles],ConceptDSyntR,_ConceptOut,_POSOut,OutDSyntR).

%% very special (and frequent) case of government-organization
% ['government-organization',\g, [':*:ARG0',['govern-01',g2, [':ARG0',g], [':ARG1',Country]
%   by "government of Country"
governmentOrganization(Roles,OutDSyntR):-
    hasRole(Roles,':*:ARG0',['govern-01',_,[':ARG0',_]],Roles1),% should check the variable!!!
    %% add unprocessed roles
    buildRoleEnvOption('government','Noun',Roles1,[],[],Env,Options),
    processRest(np(d("the"),n("government")),Env,Options,OutDSyntR).
governmentOrganization(Roles,OutDSyntR):-
    hasRole(Roles,':*:ARG0',['govern-01',_,[':ARG0',_],[':ARG1',Org]],Roles1),% should check the variable!!!
    amr2dsr(Org,_Concept,_Pos,OrgDSyntR),
    %% add unprocessed roles
    buildRoleEnvOption('government','Noun',Roles1,[],[],Env,Options),
    processRest(np(d("the"),n("government"),p("of"),OrgDSyntR),Env,Options,OutDSyntR).
% default...
governmentOrganization(Roles,OutDSyntR):-namedEntity('government-organization',Roles,OutDSyntR).
% governmentOrganization(Roles,OutDSyntR):-
%     noun('government-organization',ConceptDSyntR),
%     processConcept('Noun',['government-organization',_Ivar|Roles],ConceptDSyntR,_ConceptOut,_POSOut,OutDSyntR).
    
%%% check pronoun
pronounOrPronounRef([Pr,_],Poss):-
    pronoun(Pr,_),possessive(Pr,Poss).
pronounOrPronounRef(Var,d("my")*pe(P)*g(G)*n(N)):-
    isLegalVarName(Var),genRef(Var,_Concept,_POS,_Pr*pe(P)*g(G)*n(N)).
    
%%% dealing with different types of quantity
%%  https://github.com/amrisi/amr-guidelines/blob/master/amr.md#quantities
quantity(Roles0,OutDSyntR):-
    quantityQuant(Roles0,Roles1,DSyntR_quant),
    quantityUnit(Roles1,Roles2,DSyntR_unit),
    checkQuantUnit(DSyntR_quant,DSyntR_unit,DSyntR1),
    quantityScale(Roles2,Roles3,DSyntR1,DSyntR2),
    quantityARG1Of(Roles3,Roles4,DSyntR2,DSyntR3),
    %% add unprocessed roles
    buildRoleEnvOption('*-quantity','Special',Roles4,[],[],EnvOut,Options),
    addRestRoles(DSyntR3,EnvOut,DSyntR4),
    addOptions(Options,DSyntR4,OutDSyntR).    

 quantityQuant(Roles,Roles1,DSyntR):-
     hasRole(Roles,':quant',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
 quantityQuant(Roles,Roles,null).

 quantityUnit(Roles,Roles1,DSyntR):-
     hasRole(Roles,':unit',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
 quantityUnit(Roles,Roles,null).

 checkQuantUnit(q(Quant),Unit,QuantUnit):- % traiter cas particulier très fréquent
     isNP(Unit),changeNPD(Unit,no(Quant),QuantUnit).
 checkQuantUnit(Quant,Unit,ls(Quant,Unit)).

 quantityScale(Roles,Roles1,DSyntR,ls(DSyntR,pp(p("on"),d("the"),S,n("scale")))):-
     hasRole(Roles,':scale',AMR,Roles1),!,amr2dsr(AMR,_,_,S).
 quantityScale(Roles,Roles,DSyntR,DSyntR).

 quantityARG1Of(Roles,Roles1,DSyntR,ls(DSyntR,d("the"),n("quantity"),pro("that"),A1of)):-
     hasRole(Roles,':*:ARG1',AMR,Roles1),amr2dsr(AMR,_,_,A1of).
 quantityARG1Of(Roles,Roles,DSyntR,DSyntR).

%% reification of quant
%  Arg1: owner of the quantity
%  Arg2: number or 'many' (seldom used)
%  Arg3: type of comparison: equal, more, most
%  Arg4: thing quantified
%  Arg5: comparison with
%  Arg6: goal of the quantity 
haveQuant91(Roles0,OutDSyntR):-
    haveQuant91arg(':ARG1',Roles0,Roles1,DSyntR_Arg1),
    haveQuant91arg(':ARG2',Roles1,Roles2,DSyntR_Arg2),
    haveQuant91arg(':ARG4',Roles2,Roles3,DSyntR_Arg4),
    haveQuant91arg(':ARG5',Roles3,Roles4,DSyntR_Arg5),
    haveQuant91arg(':ARG6',Roles4,Roles5,DSyntR_Arg6),
    haveQuant91arg3(Roles5,DSyntR_Arg1,DSyntR_Arg2,DSyntR_Arg4,DSyntR_Arg5,DSyntR_Arg6,OutDSyntR).
 
 haveQuant91arg(ARG,Roles,Roles1,DSyntR):-
     hasRole(Roles,ARG,AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
 haveQuant91arg(_,Roles,Roles,null).
 
 haveQuant91arg3(Roles,DSyntR_Arg1,DSyntR_Arg2,DSyntR_Arg4,DSyntR_Arg5,DSyntR_Arg6,OutDSyntR):-
     hasRole(Roles,':ARG3',AMR,_Roles1),!,
     haveQuant91arg3aux(AMR,DSyntR_Arg1,DSyntR_Arg2,DSyntR_Arg4,DSyntR_Arg5,DSyntR_Arg6,OutDSyntR).
 haveQuant91arg3(Roles,DSyntR_Arg1,DSyntR_Arg2,DSyntR_Arg4,DSyntR_Arg5,DSyntR_Arg6,
                 ls(DSyntR_Arg1,DSyntR_Arg2,DSyntR_Arg4,DSyntR_Arg5,DSyntR_Arg6)):-
     writeln('** have-quant-91 without :ARG3':Roles).

 haveQuant91arg3aux([CMP,_],null,Arg2,Arg4,Arg5,Arg6,
     ls(v("be"),Arg2,q(Verb),Arg4,Arg5/pp(p("as"),Arg5),Arg6)):-quantVerb(CMP,Verb).
 haveQuant91arg3aux([CMP,_],Arg1,Arg2,Arg4,Arg5,Arg6,
     ls(Arg1,Arg2,q(Verb),Arg4,Arg5/pp(p("as"),Arg5),Arg6/pp(p("for"),Arg6))):-quantVerb(CMP,Verb).
 haveQuant91arg3aux(['times',_,[':quant',Q]],Arg1,Arg2,Arg4,Arg5,Arg6,
     ls(Arg1,v("be"),Arg2,no(Q),q("times"),Arg4,Arg5/pp(p("as"),Arg5),Arg6/pp(p("for"),Arg6))).
 haveQuant91arg3aux(AMR,Arg1,Arg2,Arg4,Arg5,Arg6,
     ls(Arg1,Arg2,Arg3,Arg4,Arg5/pp(p("as"),Arg5),Arg6/pp(p("for"),Arg6))):-amr2dsr(AMR,_Concept,_POS,Arg3).
 quantVerb('equal',"as many as").
 quantVerb('more',"more than").
 quantVerb('less',"less than").
 quantVerb('most',"the most").
 quantVerb(CMP,CMPs):-atom_string(CMP,CMPs).
      
%%% haveDegree1 
%   :ARG3 et ARG4 are really peculiar
%      their values must be parsed before creating DSyntR
%
% from https://github.com/amrisi/amr-guidelines/blob/master/amr.md#degree
% Arg1: domain, entity characterized by attribute (e.g. girl)
% Arg2: attribute (e.g. tall)
% Arg3: degree itself (e.g. more, less, equal, most, least, enough, too, so, to-the-point, at-least, times)
% Arg4: compared-to (e.g. (than the) BOY)
% Arg5: superlative: reference to superset
% Arg6: reference, threshold of sufficiency (e.g. (tall enough) TO RIDE THE ROLLERCOASTER)
haveDegree91(Roles0,OutDSyntR):-
    (haveDegree91arg1(Roles0,Roles1,DSyntR_subj),
     haveDegree91arg2(Roles1,Roles2,DSyntR_attr0),
     haveDegree91arg3(Roles2,Roles3,CMP,DSyntR_attr0,DSyntR_attr1),
     haveDegree91arg4(Roles3,Roles4,CMP,DSyntR_attr1,DSyntR_attr2),
     haveDegree91arg5(Roles4,Roles5,DSyntR_attr2,DSyntR_attr3),
     haveDegree91arg6(Roles5,Roles6,DSyntR_attr3,DSyntR_attr4)),
    (DSyntR_subj=null->OutDSyntR0=DSyntR_attr4;
        predicate(DSyntR_subj,DSyntR_attr4,OutDSyntR0)),
    %% add unprocessed roles
    buildRoleEnvOption('have-degree-91','Special',Roles6,[],[],EnvOut,Options),
    addRestRoles(OutDSyntR0,EnvOut,OutDSyntR1),
    addOptions(Options,OutDSyntR1,OutDSyntR).

haveDegree91arg1(Roles,Roles1,DSyntR):-
    hasRole(Roles,':ARG1',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
haveDegree91arg1(Roles,Roles,null).

haveDegree91arg2(Roles,Roles1,DSyntR):-
    hasRole(Roles,':ARG2',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
haveDegree91arg2(Roles,Roles,null):-
    writeln('** have-degree-91 without :ARG2':Roles).

haveDegree91arg3(Roles,Roles1,CMP,DSyntR0,DSyntR):-
    hasRole(Roles,':ARG3',AMR,Roles1),!,haveDegree91arg3aux(AMR,DSyntR0,CMP,DSyntR).
haveDegree91arg3(Roles,Roles,DSyntR,DSyntR).
haveDegree91arg3aux(['more',_],AttrIn,co,AttrIn*f("co")).
haveDegree91arg3aux(['more',_,Roles],AttrIn,co,ls(AttrIn*f("co"),DSyntR)):-
    amr2dsr(['more',_,Roles],_Concept,_POS,DSyntR).
haveDegree91arg3aux(['most',_],AttrIn,su,AttrIn*f("su")).
haveDegree91arg3aux(['most',_,Roles],AttrIn,su,ls(AttrIn*f("su"),DSyntR)):-
    amr2dsr(['most',_,Roles],_Concept,_POS,DSyntR).
haveDegree91arg3aux([Deg,_],AttrIn,CMP,advp(adv(DEGs),AttrIn)):-
    memberchk(Deg,['too','so','less','enough']),atom_string(Deg,DEGs),(Deg='less'->CMP=co;CMP=null).
haveDegree91arg3aux(['equal',_],AttrIn,null,advp(adv("as"),AttrIn,adv("as"))).
haveDegree91arg3aux(['times',_],AttrIn,null,ls(AttrIn,adv(deg))).
haveDegree91arg3aux([Deg,_,[':quant',[Quant,_]]],AttrIn,null,ls(Quants,Degs,AttrIn)):-
    atom_string(Deg,Degs),atom_string(Quant,Quants).
haveDegree91arg3aux(AMR,AttrIn,null,ls(AttrIn,DSyntr)):-amr2dsr(AMR,_Concept,_Pos,DSyntr).

haveDegree91arg4(Roles,Roles1,CMP,DSyntR0,DSyntR):-
    hasRole(Roles,':ARG4',AMR,Roles1),!,haveDegree91arg4aux(AMR,DSyntR0,CMP,DSyntR).
haveDegree91arg4(Roles,Roles,_,DSyntR,DSyntR).
haveDegree91arg4aux(AMR,Attr,co,pp(Attr,p("than"),DSyntr)):-amr2dsr(AMR,_Concept,_Pos,DSyntr).
haveDegree91arg4aux(AMR,Attr,su,pp(Attr,adv("in"),DSyntr)):-amr2dsr(AMR,_Concept,_Pos,DSyntr).
haveDegree91arg4aux(AMR,Attr,null,ls(Attr,DSyntr)):-amr2dsr(AMR,_Concept,_Pos,DSyntr).

haveDegree91arg5(Roles,Roles1,DSyntR0,ls(DSyntR0,p("from"),DSyntR)):-
    hasRole(Roles,':ARG5',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
haveDegree91arg5(Roles,Roles,DSyntR,DSyntR).

haveDegree91arg6(Roles,Roles1,DSyntR0,ls(DSyntR0,p("for"),DSyntR)):-
    hasRole(Roles,':ARG6',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
haveDegree91arg6(Roles,Roles,DSyntR,DSyntR).
% %%% end of haveDegree91...

%% https://github.com/amrisi/amr-guidelines/blob/master/amr.md#special-frames-for-roles
% Core roles of have-rel-role-91:
%
% :ARG0 of have-rel-role-91 entity A
% :ARG1 of have-rel-role-91 entity B
% :ARG2 of have-rel-role-91 role of entity A (must be specified)
% :ARG3 of have-rel-role-91 role of entity B (often left unspecified)
% :ARG4 of have-rel-role-91 relationship basis (contract, case; rarely used)
% Typical have-rel-role-91 roles: father, sister, husband, grandson, godfather,
%            stepdaughter, brother-in-law; friend, boyfriend, buddy, enemy; landlord, tenant etc.

haveRelRole91(Roles0,OutDSyntR):-
    haveRelRole91arg0(Roles0,Roles1,DSyntR_A),
    haveRelRole91arg1(Roles1,Roles2,DSyntR_B),
    haveRelRole91arg2(Roles2,Roles3,DSyntR_B,Role_A),
    haveRelRole91arg3(Roles3,Roles4,Role_B),
    haveRelRole91arg4(Roles4,Roles5,Basis),
    %% ajouter les rôles non traités
    buildRoleEnvOption('have-rel-role-91','Special',Roles5,[],[],EnvOut,Options),
    addRestRoles(ls(DSyntR_A,v("be"),Role_A,Role_B,Basis),EnvOut,OutDSyntR1),
    addOptions(Options,OutDSyntR1,OutDSyntR).

haveRelRole91arg0(Roles,Roles1,DSyntR):-
    hasRole(Roles,':ARG0',AMR,Roles1),!,
    amr2dsr(AMR,_Concept,_POS,DSyntR).
haveRelRole91arg0(Roles,Roles,null).

haveRelRole91arg1(Roles,Roles1,DSyntR):-
    hasRole(Roles,':ARG1',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
haveRelRole91arg1(Roles,Roles,null).

haveRelRole91arg2(Roles,Roles1,DSyntR_B,DSyntR):-
    hasRole(Roles,':ARG2',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR0),
    (pronoun(Pro,DSyntR_B),isNP(DSyntR0),possessive(Pro,Poss)->changeNPD(DSyntR0,Poss,DSyntR);
     DSyntR=ls(DSyntR0,q("of"),DSyntR_B)).
haveRelRole91arg2(Roles,Roles,_,null):-
    writeln('** have-rel-role-91 without :ARG2':Roles).

haveRelRole91arg3(Roles,Roles1,DSyntR):-
    hasRole(Roles,':ARG3',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
haveRelRole91arg3(Roles,Roles,null).

haveRelRole91arg4(Roles,Roles1,DSyntR):-
    hasRole(Roles,':ARG4',AMR,Roles1),!,amr2dsr(AMR,_Concept,_POS,DSyntR).
haveRelRole91arg4(Roles,Roles,null).

havePolarity91(Roles,OutDSyntR):-
    hasRole(Roles,':ARG2',"-",Roles1),
    %% add unprocessed roles
    buildRoleEnvOption('have-polarity-91','Special',Roles1,[],[],EnvOut,Options),
    addRestRoles(q("otherwise"),EnvOut,DSyntR1),
    addOptions(Options,DSyntR1,OutDSyntR).    
havePolarity91(Roles,q("otherwise")):-
    writeln('** have-polarity-91 with strange roles':Roles).

%%% ORDINAL-ENTITY
ordinalEntity(Roles0,ls(Value,Range/pp(p("in"),Range))):-
    ordinalEntityValue(Roles0,Roles1,Value),
    ordinalEntityRange(Roles1,_Roles2,Range).
 ordinalEntityValue(Roles,Roles1,Value):-
     hasRole(Roles,':value',Val,Roles1),ordinalEntityValueAux(Val,Value).
 ordinalEntityValue(Roles,Roles,null).
 ordinalEntityRange(Roles,Roles1,DSyntR):-
     hasRole(Roles,':range',Val,Roles1),amr2dsr(Val,_Concept,_POS,DSyntR).
 ordinalEntityRange(Roles,Roles,null).
 
 ordinalEntityValueAux('1',q("first")).
 ordinalEntityValueAux('-1',q("last")).
 ordinalEntityValueAux('-2',q("second to last")).
 ordinalEntityValueAux(NA,no(Number)*ord(true)):-
     atom(NA),atom_number(NA,Number).
 ordinalEntityValueAux(AMR,DSyntR):-
     amr2dsr(AMR,_Concept,_Pos,DSyntR).

havePurpose91(Roles,DSyntR):-
    hasRole(Roles,':ARG2',['amr-unknown',_],_)->DSyntR=q("What?");
    buildSpecialEnv(Roles,[':ARG1',':ARG2'],Env),
    applyEnv((':ARG1':A1)^(':ARG2':A2)^ls(A1,A2/pp(p("for"),A2)),Env,_,DSyntR).

%%% DATE
% https://github.com/amrisi/amr-guidelines/blob/master/amr.md#other-entities-dates-times-percentages-phone-email-urls
dateEntity(Roles,DSyntR):-
    hasRole(Roles,':time',['amr-unknown',_],_)->DSyntR=q("what time is it ?"); % VERY SPECIAL CASE
    buildSpecialEnv(Roles,[':mod',':season',':weekday',':dayperiod',':month',':day',':year',':year2',
                           ':time',':timezone',':era',':quarter',':calendar',':decade'],Env),
    applyEnv((':mod':MOD)^(':season':S)^(':weekday':WD)^(':dayperiod':DP)
               ^(':month':M)^(':day':D)^(':year':Y)^(':year2':Y2)
               ^(':time':T)^(':timezone':TZ)^(':era':E)
               ^(':quarter':Q)^(':calendar':C)^(':decade':DEC)
               ^ls(MOD,S,WD,DP,D,M/(+month(M)),
                Q/ls(no(Q)*ord(true),"quarter"),Y,Y2,T,TZ,E,C/ls("calendar:",C),DEC/ls(DEC,q("s"))),
                Env,_,DSyntR).

month(q("1") ,q("January")).
month(q("2") ,q("February")).
month(q("3") ,q("March")).
month(q("4") ,q("April")).
month(q("5") ,q("May")).
month(q("6") ,q("June")).
month(q("7") ,q("July")).
month(q("8") ,q("August")).
month(q("9") ,q("September")).
month(q("10"),q("October")).
month(q("11"),q("November")).
month(q("12"),q("December")).
month(q(M),q(M1)):-atomics_to_string(['Month',M],':',M1).

