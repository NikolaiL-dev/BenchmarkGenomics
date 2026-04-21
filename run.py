#!/usr/bin/env python3

from pathlib import Path
from os import listdir, remove
import json
from argparse import ArgumentParser, ArgumentTypeError
from subprocess import run
from sys import exit
from itertools import product

if __name__ == "__main__":
    parser = ArgumentParser(description='Run benchmark')
    parser.add_argument('-sid', '--sid', required=True, type=str, 
                        help="Set the sample ID")
    parser.add_argument('-c', '--config', required=False, default="./config/config.json", type=Path, 
                        help="Path to config file with key parameters")
    parser.add_argument('-s', '--steps', required=False, default="./config/steps.json", type=Path, 
                        help="Path to config file with lists of programs will be benchmarked")
    parser.add_argument('-e', '--exclude', required=False, default="", type=str, 
                        help="A list of steps/programs excluded from the benchmarking. " +\
                        "(for instance the following cmd excludes two steps from trimming & one from alignment timming:trimOFF,fastpALL;alignment:bwt2)")
    parser.add_argument('-es', '--earlyStop', required=False, default="", type=str, 
                        help="Set the final step of the analysis. By default it off, so, whole pipeline will be run.")
    
    args = parser.parse_args()
    
    ### init
    with open(args.config, "r") as config_file, open(args.steps, "r") as steps_file:
        config, steps = json.load(config_file), json.load(steps_file)
    
    ### exclude set parameters
    if args.exclude:
        for module in args.exclude.split(";"):
            step, cmds = module.split(":")
            for cmd in cmds.split(","):
                steps[step].remove(cmd)
                
    wd   = Path(config[args.sid])
    root = Path(config["root"])
    ref  = Path(config["hg38"])
    raw  = Path(config["raw"]).joinpath(args.sid)
    wd_trim = wd.joinpath("trimming")
                
    ### run read-based deduplication
    for rbd in steps["rbdedup"]:
        # skip step if files exist
        
        if rbd == "rbdOFF": suffix_rbd  = ""
        else: suffix_rbd  = f".{rbd}"
        script=f"rbdedup_{rbd}.sh"
        
        if wd_trim.joinpath(f"{args.sid}_R1{suffix_rbd}.fastq.gz").exists():
            _r1, _r2 = wd_trim.joinpath(f"{args.sid}_R1{suffix_rbd}.fastq.gz"), wd_trim.joinpath(f"{args.sid}_R2{suffix_rbd}.fastq.gz")
            print(f'Files have already existed. Step {rbd} was skipped.\n{_r1},\n{_r2}\n')
        else:
            if rbd != "rbdOFF":
                # run step in docker container
                print(f"Running {rbd} step...")
                run(["bash",
                f"{root.joinpath('code', 'modules', script)}",
                raw, wd_trim, args.sid, suffix_rbd, str(config["threads"]), str(config["ram"]), str(int(config["ram"]*0.8))], check=True)
                print(f"{rbd} step was finished.")
        
        # - - - - - - - - - - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - - 
        ### run TRIMMING
        for trim in steps["trimming"]:
            if trim == "trimOFF": suffix_trim  = ""
            else: suffix_trim  = f".{trim}"
            script=f"trimming_{trim}.sh"
            
            
            # skip step if files exist
            if wd_trim.joinpath(f"{args.sid}_R1{suffix_rbd}{suffix_trim}.fastq.gz").exists():
                _r1, _r2 = wd_trim.joinpath(f"{args.sid}_R1{suffix_rbd}{suffix_trim}.fastq.gz"), wd_trim.joinpath(f"{args.sid}_R2{suffix_rbd}{suffix_trim}.fastq.gz")
                print(f'Files have already existed. Step {trim} was skipped.\n{_r1},\n{_r2}\n')
            else:
                if trim != "trimOFF":
                    if rbd == "rbdOFF": local_input = raw
                    else:  local_input = wd_trim
                    # run step in docker container
                    print(f"Running {suffix_rbd}{suffix_trim} step...")
                    run(["bash",
                    f"{root.joinpath('code', 'modules', script)}",
                    local_input, wd_trim, args.sid, suffix_rbd, f"{suffix_rbd}{suffix_trim}", str(config["threads"])], check=True)
                    print(f"{trim} step was finished.")
            # - - - - - - - - - - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - - 
            ### run ALIGNMENT
            wd_alignment = wd.joinpath("alignment")
            for alignment in steps["alignment"]:
                suffix_alignment = f".{alignment}"
                
                if trim == "trimOFF" and rbd == "rbdOFF": local_input = raw
                else: local_input = wd_trim
                script=f"alignment_{alignment}.sh"
                
                # skip step if files exist
                if wd_alignment.joinpath(f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.finished").exists():
                    _bam = wd_alignment.joinpath(f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bam")
                    print(f'File have already existed. Step {alignment} was skipped.\n{_bam}\n')
                else:
                    # run step in docker container
                    print(f"Running {suffix_rbd}{suffix_trim}{suffix_alignment} step...")
                    run(["bash", f"{root.joinpath('code', 'modules', script)}",
                            local_input,
                            wd_alignment,
                            ref,
                            args.sid,
                            f"{suffix_rbd}{suffix_trim}",
                            f"{suffix_rbd}{suffix_trim}{suffix_alignment}",
                            str(config["threads"])
                            ], check=True)
                # - - - - - - - - - - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - - 
                ### run BAM-based dedup
                for bbdedup in steps["bbdedup"]:
                    if bbdedup == "bbdOFF" or rbd == "clumpify": suffix_bbdedup  = ""
                    else: suffix_bbdedup = f".{bbdedup}"
                    local_input = wd_alignment
                    script=f"bbdedup_{bbdedup}.sh"
                    
                    # skip step if files exist
                    if wd_alignment.joinpath(f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}.finished").exists():
                        _bam = wd_alignment.joinpath(f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}.bam")
                        print(f'File have already existed. Step {bbdedup} was skipped.\n{_bam}\n')
                    else:
                        if rbd != "clumpify" and bbdedup != "bbdOFF":
                            print(f"Running {suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup} step...")
                            run(["bash", f"{root.joinpath('code', 'modules', script)}",
                                    local_input,
                                    wd_alignment,
                                    args.sid,
                                    f"{suffix_rbd}{suffix_trim}{suffix_alignment}",
                                    f"{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}",
                                    str(config["threads"]),
                                    str(config["ram"]),
                                    '4'], check=True)
                    # - - - - - - - - - - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - -  - - - - - - - - - 
                    ### run variant calling
                    wd_calling = wd.joinpath("calling")
                    for calling in steps["calling"]:
                        suffix_calling = f".{calling}"
                        local_input = wd_alignment
                        script=f"calling_{calling}.sh"
                        
                        # skip step if files exist
                        c1 = wd_calling.joinpath(f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}{suffix_calling}.finished").exists()
                        c2 = wd_calling.joinpath(f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}{suffix_calling}.vcf").exists()
                        c3 = wd_calling.joinpath(f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}{suffix_calling}.vcf.gz").exists()
                        if c1 or c2 or c3:
                            print(f'File have already existed. Step {calling} was skipped.')
                        else:
                            # run step in docker container
                            print(f"Running {suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}{suffix_calling} step...")
                            run(["bash", f"{root.joinpath('code', 'modules', script)}",
                                    local_input,
                                    wd_calling,
                                    ref,
                                    args.sid,
                                    f"{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}",
                                    f"{suffix_rbd}{suffix_trim}{suffix_alignment}{suffix_bbdedup}{suffix_calling}",
                                    str(config["threads"]),
                                    str(config["ram"]),
                                    '4'
                                    ], check=True)
                
                
                _processed_bams = [
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bam",
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bam.bai",
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bqsr.bam",
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bqsr.bam.bai",
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bbdON.bam",
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bbdON.bam.bai",
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bbdON.bqsr.bam",
                f"{args.sid}{suffix_rbd}{suffix_trim}{suffix_alignment}.bbdON.bqsr.bam.bai",
                ]
                
                for _bam in _processed_bams:
                    if wd_alignment.joinpath(_bam).exists():
                        remove(wd_alignment.joinpath(_bam))
                            
                    
                    
                
