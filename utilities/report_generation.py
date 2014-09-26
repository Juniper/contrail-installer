import sys
import argparse
from prettytable import PrettyTable
from prettytable import from_csv
import os.path

def finalreport(args):
   if(not os.path.isfile(args.FILE)):
       fa=open(args.FILE,'a')
       fa.write("Testcase,Status,Log path\n")
   else:
       fa=open(args.FILE,'a')
    
   fa.write(args.testcase+','+args.status+','+args.log_path+'\n')
   fa.close()

def display(args):
   if(os.path.isfile(args.FILE)):
       fp = open(args.FILE,'r')
       mytable=from_csv(fp)
       print(mytable)
       fp.close()
   else:
       print("ERROR IN FILE DISPLAY\n")



if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("arg1",metavar='vmdetail/nwdetail', help = "enter operation to perform vmdetail/nwdetail",default="vmdetail")
    parser.add_argument("--testcase","-a2", help = "testcase executed")
    parser.add_argument("--status","-a3", help = "status of testcase pass/fail")
    parser.add_argument("--log_path","-a4", help = "reference log path", default="")
    parser.add_argument("--FILE","-f", help = "file to store   ex: --file filename.csv")
    args = parser.parse_args()
    locals()[args.arg1](args)  

#python prt_arg.py function --vm_id --vm_name --vm_

