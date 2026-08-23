# data/rdd/

**数据目录必须只放数据**——本目录只有 `tutoring.dta` 与它的下载/留档脚本。

## tutoring.dta

- **来源**：`https://github.com/quarcs-lab/data-open/raw/master/isds/tutoring.dta`（Carlos Mendez，*RDD in Stata: Evaluating a Tutoring Program* 教程配套数据集）
- **许可**：教程开放数据（与 `data/synth/` 相同口径，见 [data/README.md](../README.md) 顶部说明）
- **用途**：`stata-rdd` 断点回归（RDD）的 sharp 教学示例
- **结构**：1000 名学生，5 个变量
  - `id`：学生编号
  - `entrance_exam`：入学考试成绩（运行变量 running variable，0–100）
  - `tutoring_text`：是否参加辅导（字符串）
  - `exit_exam`：期末成绩（结果变量 outcome，0–100）
  - `tutoring`：是否参加辅导（0/1，`entrance_exam <= 70` 自动参加）
- **cutoff**：`70`（entrance_exam ≤ 70 参加辅导，> 70 不参加）——sharp RDD，100% 合规。
- **字节数校验**：26029 字节（下载脚本 `download_tutoring.sh` 的 `EXPECTED_SIZE`）

## 下载

```bash
bash data/rdd/download_tutoring.sh
```

脚本经 GitHub API 获取 base64 内容，解码后写盘，并做双重字节校验（API `size` 字段 + 落盘后 `os.path.getsize`），再用 `file` 确认是合法 Stata 数据文件。上游若更新文件导致 `EXPECTED_SIZE` 不符，脚本拒绝覆盖并报错——**先与团队确认再放宽阈值**。
