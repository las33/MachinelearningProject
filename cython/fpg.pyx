import time
from memory_profiler import memory_usage
from pyfpgrowth import find_frequent_patterns as fp_growth

def read_db_as_list(filename):    
    transactions = []
    n_transactions = 0
    with open(filename) as finput:
        f = finput.read().split('\n')
        transactions = list(map(lambda x: x.strip().split(' '), f))
        finput.close()
    transactions = list(filter(lambda x: x!=[''], transactions))
        
    return transactions

def execute_fpgrowth(transactions, support):
    initial_time = time.time()
    mem2 = memory_usage((fp_growth, (transactions, support,)), max_usage=True)
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
            
            print("\tfpgrowth:")
            execute_fpgrowth(transactions_list, support)