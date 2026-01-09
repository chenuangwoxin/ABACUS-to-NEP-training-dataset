#!/bin/bash
### HOW TO USE #################################################################################
### SYNTAX: bash abacus2nep.sh .
### NOTE: 1).'dire_name' is the directory containing running_md.log and MD_dump file.
### Fixed: 1. Windows line endings (\r) 2. Multiple atom number matches
################################################################################################
#--- DEFAULT ASSIGNMENTS ---------------------------------------------------------------------
isol_ener=0     # Shifted energy, specify the value?
viri_logi=1     # Logical value for virial, true=1, false=0
#--------------------------------------------------------------------------------------------

read_dire=$1
if [ -z "$read_dire" ]; then
    echo "Your syntax is illegal, please try again"
    exit 1
fi

# 进入目录
cd "$read_dire" || exit 1

if [ ! -f "running_md.log" ] || [ ! -f "MD_dump" ]; then
    echo "Error: running_md.log or MD_dump not found in $read_dire"
    exit 1
fi

writ_dire="NEPdataset"; writ_file="NEP-dataset.xyz";
rm -rf $writ_dire; mkdir $writ_dire

configuration=$(pwd | awk -F'/' '{print $(NF-2)"/"$(NF-1)"/"$NF}' | tr -d '\r')

# 【关键修复点】加入 head -n 1，确保只取一个数字，防止 log 里有重复记录
syst_numb_atom=$(grep "TOTAL ATOM NUMBER" running_md.log | head -n 1 | awk '{print $5}' | tr -d '\r')

echo "Detected Atom Number: '$syst_numb_atom'" # 加上单引号检查是否只有纯数字

# 读取能量
ener_values=($(grep 'etot' running_md.log | awk '{print $4}' | tr -d '\r'))

# 读取 SCF 行号
scf_lines=($(grep -n 'STEP OF MOLECULAR DYNAMICS' running_md.log | awk -F: '{print $1}' | tr -d '\r'))
scf_last=$(wc -l < running_md.log)
scf_lines+=($scf_last)

# 读取 INPUT 参数
if [ -f "INPUT" ]; then
    scf_nmax=$(grep 'scf_nmax' INPUT | head -n 1 | awk '{print $2}' | tr -d '\r')
else
    scf_nmax=100
    echo "Warning: INPUT file not found, assuming scf_nmax=100"
fi

# 读取 MDSTEP 行号
mdstep_lines=($(grep -n 'MDSTEP' MD_dump | awk -F: '{print $1}' | tr -d '\r'))
mdstep_last=$(wc -l < MD_dump)
mdstep_lines+=($mdstep_last)

N_counts=$(( ${#mdstep_lines[@]} - 2 ))

# 检查原子数是否有效
if [[ ! "$syst_numb_atom" =~ ^[0-9]+$ ]]; then
    echo "Error: Atom number is not a valid integer. Got: '$syst_numb_atom'"
    exit 1
fi

for ((i=1; i<$(( ${#mdstep_lines[@]} - 1 )); i++)); do
    ener=${ener_values[i]}

    scf_start=${scf_lines[i]}
    scf_end=${scf_lines[i+1]}
    
    if [ ! -z "$scf_nmax" ]; then
        # 增加容错：确保 sed 范围有效
        if [ ! -z "$scf_start" ] && [ ! -z "$scf_end" ] && [ "$scf_start" -lt "$scf_end" ]; then
            scf_act=$(sed -n "${scf_start},${scf_end}p" running_md.log | grep -c "ALGORITHM")
            if [ "$scf_act" -eq "$scf_nmax" ]; then
                echo "Skipping the $i structure due to non convergence"
                echo -ne "Process: ${i}/${N_counts}\r"
                continue
            fi
        fi
    fi

    md_start=${mdstep_lines[i]}
    md_end=${mdstep_lines[i+1]}
    
    # 提取当前帧
    sed -n "${md_start},${md_end}p" MD_dump > temp.file
    
    # 写入原子数
    echo "$syst_numb_atom" >> "$writ_dire/$writ_file"
    
    # 处理晶格
    latt=$(grep -A 3 "LATTICE_VECTORS" temp.file | tail -n 3 | awk '{for (i = 1; i <= NF; i++) {printf "%.8f ", $i}}' | xargs | tr -d '\r')
    
    # 计算转换系数
    conversion_value=$(echo "$latt" | awk '{a1=$1; a2=$2; a3=$3; b1=$4; b2=$5; b3=$6; c1=$7; c2=$8; c3=$9;
        V=a1*(b2*c3 - b3*c2) + a2*(b3*c1 - b1*c3) + a3*(b1*c2 - b2*c1); if (V < 0) V=-V; printf "%.8f", V/1602.1766208}')
    
    if [[ $viri_logi -eq 1 ]]; then
        viri=$(grep -A 3 "VIRIAL (kbar)" temp.file | tail -n 3 | awk '{for (i = 1; i <= NF; i++) {printf "%.8f ", $i * '$conversion_value'}}' | xargs | tr -d '\r')
        echo "Energy=$ener Lattice=\"$latt\" Virial=\"$viri\" Config_type=$configuration-$i Weight=1.0 Properties=species:S:1:pos:R:3:forces:R:3" >> "$writ_dire/$writ_file"
    else
        echo "Energy=$ener Lattice=\"$latt\" Config_type=$configuration-$i Weight=1.0 Properties=species:S:1:pos:R:3:forces:R:3" >> "$writ_dire/$writ_file"
    fi
    
    # 提取原子坐标和力
    grep -A $syst_numb_atom "INDEX" temp.file | tail -n $syst_numb_atom | awk '{print $2,$3,$4,$5,$6,$7,$8}' >> "$writ_dire/$writ_file"
    
    echo -ne "Process: ${i}/${N_counts}\r"
    rm -f temp.file
done

echo
echo "All done."