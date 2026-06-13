# A同学项目推进文档：GUI与预处理集成

## 1. 角色定位

你负责的是整个工程里“看得见、点得到、演示得出来”的部分。

你的核心任务不是写算法，而是保证：

1. 所有验收动作都能通过 GUI 完成。
2. 所有算法结果都能稳定显示出来。
3. 实时采集的人脸可以回放到预处理页复现。

## 2. 你负责的目录

```text
run_main.m
ui/
preprocess/
integration/ 中偏界面触发的部分
```

你不要主动去改 `ml/` 目录里的算法逻辑，除非只是接接口时的小修。

## 3. 你负责的功能清单

### 3.1 主界面

必须完成：

1. 主窗口
2. 两个 tab
3. 状态文本区
4. 图像显示区
5. 结果表显示区

### 3.2 预处理页

必须完成：

1. 输入图像
2. 清除图像
3. 灰度化
4. 均衡化
5. 获取图像参数
6. 绘制灰度直方图
7. 图像缩放
8. 图像旋转
9. 人脸捕获
10. 人脸校准
11. 启动摄像头
12. 停止摄像头

### 3.3 识别页

必须完成：

1. PCA 参数输入框
2. SVM 参数输入框
3. 测试集全量识别按钮
4. 单张静态识别按钮
5. 平均脸显示按钮
6. 特征脸显示按钮
7. 实时识别按钮
8. 结果文本区
9. 结果表
10. 原始摄像头画面区
11. 识别人脸画面区
12. 送入预处理页复现按钮

## 4. 你必须提供给 B 同学的输入

你需要保证传给算法模块的数据格式稳定。

### 4.1 单张识别时

传给 B 的 `imageData` 必须是以下两种之一：

1. 原始图像矩阵
2. 已经裁剪/对齐好的人脸图像矩阵

这个格式一旦定了，不能中途乱改。

### 4.2 实时识别时

你每次至少要准备：

1. 当前原始帧
2. 当前检测框
3. 当前裁剪后人脸
4. 当前对齐后人脸

### 4.3 回放到预处理页时

你要输出统一的 `replayPkg`：

```matlab
replayPkg.rawFrame
replayPkg.faceBox
replayPkg.faceImage
replayPkg.alignedFace
replayPkg.landmarks
replayPkg.timestamp
```

## 5. 你调用 B 同学接口的时机

### 5.1 全量识别按钮

你要做：

1. 读参数框
2. 调 `train_pca_svm_model`
3. 调 `run_batch_test`
4. 把结果显示成表

### 5.2 单张识别按钮

你要做：

1. 读参数框
2. 调 `train_pca_svm_model`
3. 选图片
4. 调 `predict_face_identity`
5. 显示预测结果

### 5.3 实时识别按钮

你要做：

1. 打开摄像头
2. 每帧做人脸检测和对齐
3. 把对齐后人脸送给 `predict_face_identity`
4. 刷新两个画面和识别文本
5. 保存 `replayPkg`

## 6. 你的代码文件建议

### 6.1 启动入口

`run_main.m`

职责：

1. 初始化 `appState`
2. 创建主窗口
3. 创建两个 tab
4. 绑定回调

### 6.2 UI 层

`ui/create_main_window.m`

职责：

1. 创建主窗体
2. 创建 tab group
3. 分配布局

`ui/create_preprocess_tab.m`

职责：

1. 创建预处理页按钮
2. 创建预处理页坐标轴
3. 创建参数显示文本区

`ui/create_recognition_tab.m`

职责：

1. 创建识别页按钮
2. 创建结果表
3. 创建实时显示区域

`ui/bind_callbacks.m`

职责：

1. 给所有按钮绑定回调
2. 只做绑定，不写大量业务逻辑

### 6.3 预处理层

`preprocess/import_image.m`
`preprocess/clear_image_state.m`
`preprocess/convert_to_gray.m`
`preprocess/equalize_image.m`
`preprocess/compute_image_stats.m`
`preprocess/draw_histogram.m`
`preprocess/scale_image.m`
`preprocess/rotate_image.m`
`preprocess/detect_face.m`
`preprocess/align_face.m`
`preprocess/camera_start.m`
`preprocess/camera_stop.m`
`preprocess/camera_snapshot.m`
`preprocess/export_replay_state.m`

## 7. 你的开发顺序

### 第一步

先把空壳界面搭起来：

1. 主窗口
2. 两个 tab
3. 所有按钮
4. 两块图像区
5. 一块结果表

### 第二步

把预处理页做通：

1. 输入图像
2. 清除图像
3. 灰度化
4. 均衡化
5. 图像参数
6. 直方图
7. 缩放
8. 旋转

### 第三步

加摄像头：

1. 启动
2. 停止
3. 单帧取图
4. 原始帧显示

### 第四步

等 B 同学接口稳定后接入：

1. 单张识别
2. 全量识别
3. 平均脸
4. 特征脸
5. 实时识别

### 第五步

补最关键的验收动作：

1. 全量识别结果表
2. 采集脸送回预处理页复现

## 8. 你每天要确认的接口

每天都问 B 同学这几个问题：

1. `predict_face_identity` 的输入还是不是图像矩阵？
2. `result.name`、`result.elapsedMs` 这些字段有没有改？
3. `run_batch_test` 的 `perImageResults` 结构有没有改？
4. `build_average_face` 和 `build_eigenface_preview` 的输出形式有没有改？

如果改了，你这边显示逻辑也要一起改。

## 9. 你的验收红线

你这边如果出现下面任一问题，验收会直接掉分：

1. 功能必须靠命令行触发，不是靠 GUI
2. 全量识别没有结果表
3. 实时识别不能把采集脸回放到预处理页
4. 按钮能点但无响应或报错

## 10. 你最终要交付什么

1. 一个能打开的主界面
2. 完整的预处理页
3. 完整的识别页
4. 实时识别显示
5. 结果表展示
6. 采集脸回放复现功能

