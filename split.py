import numpy as np
from ase.io import read, write
import random

def split_dataset(input_file, train_ratio=0.8, seed=42):
    print(f"正在读取 {input_file} ... (可能需要一点时间)")

    # 1. 读取由 Shell 脚本生成的大文件
    # index=':' 表示读取所有帧
    atoms_list = read(input_file, index=':', format='extxyz')

    total_frames = len(atoms_list)
    print(f"共读取到 {total_frames} 帧结构。")

    if total_frames == 0:
        print("错误：文件中没有数据！")
        return

    # 2. 随机打乱
    random.seed(seed)
    random.shuffle(atoms_list)

    # 3. 计算切分点
    n_train = int(total_frames * train_ratio)

    train_data = atoms_list[:n_train]
    test_data = atoms_list[n_train:]

    print(f"划分结果: 训练集 {len(train_data)} 帧, 测试集 {len(test_data)} 帧")

    # 4. 写入文件
    # NEP/DeepMD 训练通常只需要这就行了
    print("正在写入 train.xyz ...")
    write('train.xyz', train_data, format='extxyz')

    print("正在写入 test.xyz ...")
    write('test.xyz', test_data, format='extxyz')

    print("完成！")

if __name__ == "__main__":
    # 这里填 Shell 脚本生成的那个文件的路径
    dataset_path = "NEPdataset/NEP-dataset.xyz"

    split_dataset(dataset_path)
