from opencog.atomspace import Atom, get_type, types
from copy import copy, deepcopy
from functools import *
from itertools import permutations
from util import *

def coerce_tree(x):
    assert type(x) != type(None)
    if isinstance(x, tree):
        return x
    else:
        return tree(x)

class tree:
    def __init__(self, op, *args):
        # Transparently allow using passing a list or using it in the more streamlined way
        # (better for constructing trees by hand)
        if len(args) and isinstance(args[0], list):
            args = args[0]
        # Transparently record Links as strings rather than Handles
        assert type(op) != type(None)
        if len(args):
            if isinstance(op, Atom):
                self.op = op.type_name
            else:
                self.op = op
            self.args = [coerce_tree(x) for x in args]
        else:
            self.op = op
            self.args = args

    def __str__(self):
        if self.is_leaf():
            if isinstance(self.op, Atom):
                return self.op.name+':'+self.op.type_name
            else:
                return 'tree:'+str(self.op)
        else:
            return '(' + str(self.op) + ' '+ ' '.join(map(str, self.args)) + ')'

    def __hash__(self):
        return hash( self.to_tuple() )

    def is_variable(self):
        "A variable is an int starting from 0"
        return isinstance(self.op, int)
    
    def is_leaf(self):
        return len(self.args) == 0
    
    def __cmp__(self, other):
        if not isinstance(other, tree):
            return cmp(tree, type(other))
        #print self.to_tuple(), other.to_tuple()
        return cmp(self.to_tuple(), other.to_tuple())
    
    def to_tuple(self):
        # Atom doesn't support comparing to different types in the Python-standard way.
        if isinstance(self.op, Atom):
            #assert type(self.op.h) != type(None)
            return self.op.h.value()
            #return self.op.type_name+':'+self.op.name # Easier to understand, though a bit less efficient
        else:
            return tuple([self.op]+[x.to_tuple() for x in self.args])

def tree_from_atom(atom):
    if atom.is_node():
        return tree(atom)
    else:
        args = [tree_from_atom(x) for x in atom.out]
        return tree(atom.type_name, args)

def atom_from_tree(tree, a):
    if tree.is_variable():
        return a.add(types.VariableNode, name='$'+str(tree.op))
    elif tree.is_leaf():
        # Node (simply the handle)
        if isinstance (tree.op, Atom):
            return tree.op
        # Empty Link
        # Currently still recorded as an Atom (wrong?)
    else:
        out = [atom_from_tree(x, a) for x in tree.args]
        return a.add(get_type(tree.op), out=out)

# Further code adapted from AIMA-Python under the MIT License (see http://code.google.com/p/aima-python/)
def unify(x, y, s,  vars_only = False):
    """Unify expressions x,y with substitution s; return a substitution that
    would make x,y equal, or None if x,y can not unify. x and y can be
    variables (e.g. 1, Nodes, or tuples of the form ('link type name', arg0, arg1...)
    where arg0 and arg1 are any of the above. NOTE: If you unify two Links, they 
    must both be in tuple-tree format, and their variables must be standardized apart.
    >>> ppsubst(unify(x + y, y + C, {}))
    {x: y, y: C}
    """
    print "unify %s %s" % (str(x), str(y))
    
    if vars_only:
        if isinstance(x, tree) and isinstance(y, tree):
            if x.is_variable() != y.is_variable():
                return None

    if s == None:
        return None
    elif x == y:
        return s
    elif isinstance(x, tree) and x.is_variable():
        return unify_var(x, y, s, vars_only)
    elif isinstance(y, tree) and y.is_variable():
        return unify_var(y, x, s, vars_only)
        
    elif isinstance(x, tree):
        assert isinstance(y, tree)

        s2 = unify(x.op, y.op, s, vars_only)
        return unify(x.args,  y.args, s2, vars_only)

    # Handle conjunctions.
    elif isinstance(x, tuple) and isinstance(y, tuple) and len(x) == len(y):
        for permu in permutations(x):
            s2 = unify(list(permu), list(y), s, vars_only)
            if s2 != None:
                return s2
        return None

    # Recursion to handle arguments.
    elif isinstance(x, list) and isinstance(y, list) and len(x) == len(y):
            # unify all the arguments (works with any number of arguments, including 0)
            s2 = unify(x[0], y[0], s, vars_only)
            return unify(x[1:], y[1:], s2, vars_only)
        
    else:
        return None

def unify_var(var, x, s, vars_only):
    if var in s:
        return unify(s[var], x, s, vars_only)
    elif occur_check(var, x, s):
        return None
    else:
        return extend(s, var, x)

def occur_check(var, x, s):
    """Return true if variable var occurs anywhere in x
    (or in subst(s, x), if s has a binding for x)."""

    if x.is_variable() and var == x:
        return True
    elif x.is_variable() and s.has_key(x):
        return occur_check(var, s[x], s)
    # What else might x be? 
    elif not x.is_leaf():
        # Compare link type and arguments
#        return (occur_check(var, x.op, s) or # Not sure that's necessary
#                occur_check(var, x.args, s))
        return any([occur_check(var, a, s) for a in x.args])
    else:
        return False

def extend(s, var, val):
    """Copy the substitution s and extend it by setting var to val;
    return copy.
    
    >>> initial = {'x': 1}
    >>> extend({'x': 1}, 'y', 2)
    {'y': 2, 'x': 1}
    >>> initial
    {'x': 1}
    """
    s2 = s.copy()
    s2[var] = val
    return s2
    
def subst(s, x):
    """Substitute the substitution s into the expression x.
    >>> subst({x: 42, y:0}, F(x) + y)
    (F(42) + 0)
    """
    if x.is_variable(): 
        return s.get(x, x)
    elif x.is_leaf(): 
        return x
    else: 
        #return tuple([x[0]]+ [subst(s, arg) for arg in x[1:]])
        return tree(x.op, [subst(s, arg) for arg in x.args])

def standardize_apart(tree, dic={}):
    """Replace all the variables in tree with new variables.
    >>> standardize_apart(expr('F(a, b, c) & G(c, A, 23)'))
    (F(v_1, v_2, v_3) & G(v_3, A, 23))
    >>> is_variable(standardize_apart(expr('x')))
    True
    """

    if tree.is_variable:
        if tree in dic:
            return dic[tree]
        else:
            standardize_apart.counter += 1
            v = standardize_apart.counter
            dic[tree] = v
            return v
    elif not isinstance(tree, tuple):
        return tree
    else: 
        return tuple([tree[0]]+
                    [standardize_apart(a, dic) for a in tree[1:]])

standardize_apart.counter = 0

# These functions print their arguments in a standard order
# to compensate for the random order in the standard representation

def ppsubst(s):
    """Print substitution s"""
    ppdict(s)