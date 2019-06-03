import itertools
import copy
import time
import json

from memory_profiler import memory_usage
from collections import Counter
from pyfpgrowth import find_frequent_patterns as fp_growth

support = 0
n_list = {}

def read_db_as_list(filename):    
    transactions = []
    n_transactions = 0
    with open(filename) as finput:
        f = finput.read().split('\n')
        transactions = list(map(lambda x: x.strip().split(' '), f))
        finput.close()
    transactions = list(filter(lambda x: x!=[''], transactions))
        
    return transactions


def make_itemset_1(transactions, support):    
    n_transactions = len(transactions)
    itemset_1 = dict(Counter(list(itertools.chain.from_iterable(transactions))))
    
    itemset_1 = dict(filter(lambda x: x[1] >= support, itemset_1.items()))
    return itemset_1


class PPCNode:
    def __init__(self):
        self.pre_order = None
        self.post_order = None
        self.count = None
        self.label = None
        self.parent = None
        self.child = None
        self.sibling = None


class FPTNode:
    def __init__(self):
        self.equivalent_items = None
        self.child_nodes = None
        self.label = None
        self.itemset = None
        self.support = None

        
def create_node(root, label):
    node = PPCNode()
    node.label = label
    node.count = 1
    node.parent = root
    return node


def insert_ppc_node(root, item):
    if root.child is None:
        node = create_node(root, item)
        root.child = node
        return root.child
    elif root.child.label == item:
        root.child.count += 1
        return root.child
    elif root.child.sibling is None:
        node = create_node(root, item)
        root.child.sibling = node
        return root.child.sibling
    else:
        current_sibling = root.child.sibling
        last_sibling = None
        while current_sibling is not None:
            if current_sibling.label == item:
                current_sibling.count += 1
                return current_sibling
            else:
                last_sibling = current_sibling
                current_sibling = current_sibling.sibling
        node = create_node(root, item)
        last_sibling.sibling = node        
        return node


def pre_post(root, pre=0, post=0):
    root.pre_order = pre
    post_ = post
    if root.child is not None:
        root.child.pre_order = pre + 1
        pre, post_ = pre_post(root.child, root.child.pre_order, post)
    root.post_order = post_
    if root.sibling is not None:
        root.sibling.pre_order = pre + 1
        pre, post_ = pre_post(root.sibling, root.sibling.pre_order, root.post_order + 1)
        return pre, post_
    return pre, post_ + 1    


def build_ppc_tree(transactions, itemset_1):
    root = PPCNode()
    
    main_keys = list(itemset_1.keys())
    for transaction in transactions:
        t = list(filter(lambda x: x in main_keys, transaction))
        t = list(map(lambda x: (x, itemset_1[x]), t))
        t.sort(key=lambda x: x[0])
        t.sort(key=lambda x: x[1], reverse=True)
        
        root_aux = root
        for item in t:
            root_aux = insert_ppc_node(root_aux, item[0])
            
    pre_post(root)
    return root


def print_tree(root):
    print(root.label, root.pre_order, root.post_order)
    if root.child:
        print_tree(root.child)
    if root.sibling:
        print_tree(root.sibling)


def make_n_list(root, n_list={}):
    if root.label:
        if root.label not in n_list:
            n_list[root.label] = []
        n_list[root.label].append(((root.pre_order, root.post_order), root.count))
    if root.child:
        make_n_list(root.child, n_list)
    if root.sibling:
        make_n_list(root.sibling, n_list)

        
def NL_interserction(n_list1, n_list2, minsup):
    n_list_result = []
    for k in n_list1:
        for l in n_list2:
            if k[0][0] < l[0][0] and k[0][1] > l[0][1]:                 
                n_list_result.append((k[0], l[1]))
    d = {x:0 for x, _ in n_list_result} 
    for name, num in n_list_result: d[name] += num 
    n_list_result = list(map(tuple, d.items()))
    return n_list_result


def find_subsets(items, n):
    return list(itertools.combinations(items, n))


def get_all_subsets(items):
    subsets = [find_subsets(items, i) for i in range(len(items)+1)]
    subsets = ['-'.join(map(str, item)) for item in list(itertools.chain.from_iterable(subsets))]
    return subsets[1:]


def get_n_list(key, n_list):
    return n_list[key] if key in n_list else []


def building_pattern_tree(cur_no, next_nos, father_no, support, n_list):
    if cur_no.equivalent_items is None:
        cur_no.equivalent_items = []
        
    cur_no.child_nodes = []
    if father_no is not None:
        p1 = get_n_list('-'.join([father_no.label, cur_no.label]), n_list)
    else:
        p1 = get_n_list(cur_no.label, n_list)
        
    for i in next_nos:
        if father_no is not None:
            p2 = get_n_list('-'.join([father_no.label, i.label]), n_list)
        else:
            p2 = get_n_list(i.label, n_list)
            
        p = NL_interserction(p2, p1, support)
        p_support = sum([item[1] for item in p])
        
        if p_support == cur_no.support:
            cur_no.equivalent_items += [i.label]
        elif p_support >= support:
            child = FPTNode()
            child.label = i.label
            child.support = p_support
            cur_no.child_nodes += [child]
            if father_no is not None:
                n_list['-'.join([father_no.label, cur_no.label, child.label])] = p
            else:
                n_list['-'.join([cur_no.label, child.label])] = p

    if father_no is not None:
        cur_no.label = '-'.join([father_no.label, cur_no.label])
    
    if len(cur_no.equivalent_items) > 0:
        subsets = get_all_subsets(cur_no.equivalent_items)
        cand_itemsets = [('-'.join([cur_no.label, item]), cur_no.support) for item in subsets]
    
    if len(cur_no.child_nodes) > 0:
        for child in cur_no.child_nodes:
            aheads_ = [i for i in cur_no.child_nodes[cur_no.child_nodes.index(child)+1:]]
            child.equivalent_items = list(cur_no.equivalent_items)
            building_pattern_tree(child, aheads_, cur_no, support, n_list)


def prepostplus(transactions, support):    
    print("prepostplus(transactions, support)")
    n_list = {}
    itemset_1 = make_itemset_1(transactions, support)
    tree = build_ppc_tree(transactions, itemset_1)
    make_n_list(tree, n_list)

    items_ordered = list(itemset_1.items())
    items_ordered.sort(key=lambda x: x[0], reverse=True)
    items_ordered.sort(key=lambda x: x[1])
    items_ordered = [x[0] for x in items_ordered]

    nodes = []
    for key in list(items_ordered):
        node = FPTNode()
        node.label = key
        node.support = sum([item[1] for item in n_list[key]])
        nodes.append(node)

    for node in list(nodes):
        aheads = nodes[nodes.index(node)+1:]
        building_pattern_tree(node, aheads, None, support, n_list)
        

def execute_prepostplus(transactions, support):
    initial_time = time.time()
    mem1 = memory_usage((prepostplus, (transactions, support)), max_usage=True)
    final_time = time.time()
    print("\t\tExecution time (s):", final_time - initial_time)
    print("\t\tMemory usage (Mb):", mem1)

def main():    
    input_files = ["databases/mushroom.txt", "databases/connect.txt", "databases/pumsb.txt"]
    min_sups = {
        "databases/mushroom.txt": [.25, .2, .15, .1, .05],
        "databases/connect.txt": [.6, .55, .5, .45, .4],
        "databases/pumsb.txt": [.7, .65, .6, .55, .5]
    }

    for file in input_files:
        print("Database:", file)
        transactions_list = read_db_as_list(file)
        for sup in min_sups[file]:
            print("\tSupport:", sup)
            support = len(transactions_list) * sup
            
            print("\tprepostplus:")
            execute_prepostplus(transactions_list, support)