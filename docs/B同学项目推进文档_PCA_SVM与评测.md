# B同学项目推进文档：PCA_SVM与评测

## 1. 角色定位

你负责的是整个工程里“识别得准不准、结果能不能统计、平均脸和特征脸能不能展示”的部分。

你的核心任务不是做界面，而是保证：

1. 训练集和测试集划分符合验收要求。
2. 手写 PCA + 手写 SVM 链路稳定可复现。
3. 单张识别、全量识别、实时识别接口统一。
4. 结果能直接被 A 同学拿去显示。

## 2. 你负责的目录

```text
ml/
models/
results/ 中偏算法产物的部分
integration/ 中偏模型调用的部分
```

你不要主动去大改 `ui/` 和 `preprocess/` 的界面层，除非只是配合接口联调。

## 3. 你负责的功能清单

### 3.1 数据集部分

必须完成：

1. 读取原始数据集
2. 核查原始数据总数
3. 导出数据集完整性核查表
4. 按 8:2 划分训练集和测试集
5. 导出训练集/测试集划分清单

### 3.2 模型部分

必须完成：

1. 训练前统一预处理
2. 手写 PCA 降维训练
3. 手写 SVM 分类训练
4. 模型保存和加载

### 3.3 预测部分

必须完成：

1. 单张识别
2. 测试集全量识别
3. 实时帧识别
4. Top-k 候选输出

### 3.4 展示产物部分

必须完成：

1. 平均脸
2. 特征脸
3. 测试集准确率统计表
4. 实时识别统计表
5. 创新小项目算法部分

## 4. 你必须先冻结的规则

这些东西一旦定了，中途不要随便改：

1. 人脸输入尺寸，例如 `112x92`
2. 标签提取规则
3. 图像是先灰度化再 PCA，还是先做其它归一化
4. `predict_face_identity` 的返回字段
5. `run_batch_test` 的结果表字段
6. 手写 SVM 的多分类策略，例如 `one-vs-rest`

如果必须改，就要同步通知 A 同学。

## 5. 你必须提供给 A 同学的接口

### 5.1 训练接口

```matlab
model = train_pca_svm_model(trainDir, pcaDim, svmC, options)
```

你必须保证返回：

```matlab
model.status
model.message
model.labels
model.imageSize
model.meanFace
model.eigenfaces
model.pcaDim
model.svmC
model.svmParams
model.trainSummary
```

你必须保证：

1. `model.svmParams` 只保存你们自己手写 SVM 的参数。
2. 不允许返回 MATLAB 现成分类器对象。
3. 如果做多分类，参数结构里要能看出 `one-vs-rest` 或 `one-vs-one` 的组织方式。

### 5.2 单张识别接口

```matlab
result = predict_face_identity(model, imageData, options)
```

你必须保证返回：

```matlab
result.status
result.message
result.name
result.topKNames
result.topKScores
result.faceBox
result.alignedFace
result.elapsedMs
```

### 5.3 测试集全量识别接口

```matlab
batchResult = run_batch_test(model, testDir, options)
```

你必须保证返回：

```matlab
batchResult.status
batchResult.message
batchResult.accuracy
batchResult.totalElapsedMs
batchResult.avgElapsedMs
batchResult.perImageResults
batchResult.confusionSummary
```

其中 `perImageResults` 每条至少有：

```matlab
trueName
predName
isCorrect
elapsedMs
imagePath
```

### 5.4 展示接口

```matlab
avgFace = build_average_face(model)
eigenfaceImgs = build_eigenface_preview(model, k)
```

你必须保证：

1. A 同学拿到图像矩阵就能直接显示
2. 不要返回复杂自定义对象

### 5.5 数据集合规接口

```matlab
manifest = export_dataset_manifest(dataDir, trainDir, testDir, classSizeInfo)
```

你必须保证输出：

```matlab
manifest.totalRawCount
manifest.expectedRawCount
manifest.trainCount
manifest.testCount
manifest.splitRatio
manifest.perClassSummary
manifest.status
```

## 6. 你的代码文件建议

`ml/load_dataset.m`

职责：

1. 读取所有图片
2. 输出标签和路径

`ml/export_dataset_manifest.m`

职责：

1. 核对原始数据总数
2. 核对每类样本数
3. 导出清单

`ml/split_dataset_2_8.m`

职责：

1. 生成训练集和测试集划分
2. 保证 8:2 比例

`ml/preprocess_for_model.m`

职责：

1. 统一输入尺寸
2. 统一灰度化
3. 统一模型前预处理

`ml/train_pca_svm_model.m`

职责：

1. 训练手写 PCA
2. 训练手写 SVM
3. 返回模型结构体

`ml/predict_face_identity.m`

职责：

1. 处理单张输入
2. 返回预测结果和 top-k

`ml/run_batch_test.m`

职责：

1. 对整个测试集批量预测
2. 输出准确率和逐图结果

`ml/build_average_face.m`
`ml/build_eigenface_preview.m`

职责：

1. 生成可视化结果

`ml/evaluate_model.m`

职责：

1. 汇总测试集精度
2. 汇总实时识别精度和耗时

## 7. 你的开发顺序

### 第一步

先做数据集合规：

1. 读原始数据
2. 算总数
3. 按类统计
4. 导出核查表

### 第二步

再做训练测试划分：

1. 按 8:2 划分
2. 导出清单
3. 保证可复现

### 第三步

把模型离线跑通：

1. 统一预处理
2. 手写 PCA
3. 手写 SVM
4. 单张预测

这一阶段必须避免：

1. 调用现成 PCA 分类接口代替主算法
2. 调用现成 SVM 分类器代替主算法

### 第四步

把全量识别跑通：

1. 整个测试集预测
2. 输出总体准确率
3. 输出逐图结果表

### 第五步

把展示产物跑通：

1. 平均脸
2. 特征脸
3. Top-k 候选

### 第六步

再支持实时识别输入：

1. 接收 A 同学给的对齐人脸
2. 直接返回识别结果
3. 保证速度稳定

## 8. 你每天要确认的接口

每天都要和 A 同学对齐：

1. `imageData` 传进来的是原图还是对齐后人脸
2. `predict_face_identity` 是否仍返回 `name`、`elapsedMs`
3. `batchResult.perImageResults` 的字段有没有变
4. 平均脸和特征脸是否仍是图像矩阵
5. 数据集路径是否仍然按相对路径组织

## 9. 你的验收红线

你这边如果出问题，验收会直接掉分：

1. 数据集数量不符合“班级人数×10”
2. 训练集和测试集不是 8:2
3. 全量识别没有总体准确率和逐图结果表
4. 平均脸和特征脸无法展示
5. 实时识别接口和静态识别接口不统一
6. PCA 或 SVM 实际上调用了现成库实现

## 10. 你最终要交付什么

1. 数据集完整性核查表
2. 训练集/测试集划分清单
3. 训练接口
4. 单张识别接口
5. 全量识别接口
6. 实时识别接口
7. 平均脸
8. 特征脸
9. 精度和耗时统计表
10. 创新小项目算法部分
