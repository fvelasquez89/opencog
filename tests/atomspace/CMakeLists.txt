OPENCOG_ADD_ATOM_TYPES(atom_types.script
	atom_types.h
	atom_types.definitions
	atom_types.inheritance
	atom_test_types.scm)

LINK_LIBRARIES(
	atomspace
	${Boost_SIGNALS_LIBRARY}
)

IF(HAVE_GUILE)
	ADD_CXXTEST(AtomTableUTest HandleEntry.cc)
	TARGET_LINK_LIBRARIES(AtomTableUTest smob server spacetime)
ENDIF(HAVE_GUILE)

ADD_CXXTEST(ClassServerUTest)
ADD_CXXTEST(AtomUTest)
ADD_CXXTEST(NodeUTest)
ADD_CXXTEST(LinkUTest)
ADD_CXXTEST(TruthValueUTest)
ADD_CXXTEST(SimpleTruthValueUTest)
ADD_CXXTEST(IndefiniteTruthValueUTest)

ADD_CXXTEST(CompositeTruthValueUTest)
TARGET_LINK_LIBRARIES(CompositeTruthValueUTest savable spacetime)

ADD_CXXTEST(AttentionValueUTest)
ADD_CXXTEST(AtomSpaceUTest HandleEntry.cc)
ADD_CXXTEST(AtomSpaceImplUTest HandleEntry.cc)
ADD_CXXTEST(AtomSpaceAsyncUTest)
ADD_CXXTEST(HandleEntryUTest HandleEntry.cc)
ADD_CXXTEST(HandleMapUTest)
ADD_CXXTEST(TLBUTest)
