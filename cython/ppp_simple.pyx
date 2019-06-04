import itertools
import time
import copy
from memory_profiler import memory_usage
from collections import Counter


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
    n_list_result = list(filter(lambda x: x[1] >= minsup, n_list_result))
    return n_list_result


def make_n2_list(n_list, items_ordered, support):
    n2_list = {}
    for i, x in enumerate(items_ordered):
        for j in range(i+1, len(items_ordered)):
            n_list_result = NL_interserction(n_list[x], n_list[items_ordered[j]], support)
            if len(n_list_result) > 0:
                key = '-'.join([x, items_ordered[j][0]])
                n2_list[key] = n_list_result
    return n2_list


def find_subsets(items, n):
    return list(itertools.combinations(items, n))


def get_all_subsets(items):
    subsets = [find_subsets(items, i) for i in range(len(items)+1)]
    subsets = ['-'.join(map(str, item)) for item in list(itertools.chain.from_iterable(subsets))]
    return subsets[1:]


def get_n_list(all_n_list, key):
    return all_n_list[key] if key in all_n_list else []


def building_pattern_tree(node, cad_items, parent_fit, support, all_n_list, items_ordered):    
    node.equivalent_items = []
    node.child_nodes = []
    next_cad_items = []    
    p1 = node.itemset
    p1_n_list = get_n_list(all_n_list, '-'.join(p1))
    for item in cad_items:
        p2 = [item] + p1[1:]
        p = [item] + p1
        p2_n_list = get_n_list(all_n_list, '-'.join(p2))        
        p_n_list = NL_interserction(p2_n_list, p1_n_list, support)
        p_support = sum([i[1] for i in p_n_list])
        p_key = '-'.join(p)
        
        if len(p_n_list) > 0: # add n_list for new k-itemset            
            if p_key not in all_n_list:
                all_n_list[p_key] = []
            all_n_list[p_key] += p_n_list
            
        if p_support == node.support:
            node.equivalent_items += [item]
        elif p_support >= support:
            node_ = FPTNode()
            node_.label = item
            node_.itemset = p
            node_.support = p_support
            node.child_nodes += [node_]
            next_cad_items += [item]
    
    nd_fit = []        
    if len(node.equivalent_items) > 0:
        subsets = get_all_subsets(node.equivalent_items)
        cand_itemsets = [('-'.join([item, node.label]), node.support) for item in subsets]
        if len(parent_fit) == 0:
            nd_fit = cand_itemsets
        else:
            nd_fit = []
            for cand_item in cand_itemsets:
                for parent_item in parent_fit:
                    nd_fit.append(('-'.join([cand_item[0], parent_item[0]]), node.support))
                        

    if len(node.child_nodes) > 0:
        for n in node.child_nodes:
            aheads_ = [i for i in items_ordered[:items_ordered.index(n.label)] if i in next_cad_items]
            building_pattern_tree(n, aheads_, nd_fit, support, all_n_list, items_ordered)


def prepostplus(transactions, support):   
    itemset_1 = make_itemset_1(transactions, support)
    tree = build_ppc_tree(transactions, itemset_1)
    
    n_list = {}
    make_n_list(tree, n_list)
    
    F = list(itemset_1.items())
    F.sort(key=lambda x: x[0])
    F.sort(key=lambda x: x[1], reverse=True)

    items_ordered = [x[0] for x in F]
    
    n2_list = make_n2_list(n_list, items_ordered, support)
    
    all_n_list = copy.deepcopy(n2_list)
    
    for key, n_list in list(n2_list.items()):
        item = key[:key.index('-')]
        aheads = items_ordered[:items_ordered.index(item)]
        node = FPTNode()
        node.label = key
        node.itemset = key.split('-')
        node.support = sum([item[1] for item in n_list])
        building_pattern_tree(node, aheads, [], support, all_n_list, items_ordered)


def execute_prepostplus_simple(transactions, support):
    initial_time = time.time()
    mem2 = memory_usage((prepostplus, (transactions, support,)), max_usage=True)
    final_time = time.time()
    print("\t\tExecution time (s):", final_time - initial_time)
    print("\t\tMemory usage (Mb):", mem2)


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
            
            print("\prepostplus_simple:")
            execute_prepostplus_simple(transactions_list, support)