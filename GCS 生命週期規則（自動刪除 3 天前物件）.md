

## GCS 生命週期規則（自動刪除 3 天前物件）

不用寫 shell、也不需公開 bucket。給 bucket 設定 lifecycle，滿足條件就自動刪除。
只清 linebot_images/ 目錄、刪 3 天以上且為現行版本

建立 lifecycle.json：
```
{
  "rule": [
    {
      "action": { "type": "Delete" },
      "condition": {
        "age": 3,
        "isLive": true,
        "matchesPrefix": ["linebot_images/"]
      }
    }
  ]
}
```
套用到 bucket：
```
gsutil lifecycle set lifecycle.json gs://image-gen-im-2025
```
檢視確認：
```
gsutil lifecycle get gs://image-gen-im-2025
```
備註

	-	age: 3 = 物件建立滿 3 天即符合刪除條件。
	-	只想全桶清理就拿掉 matchesPrefix。
	-	若有開啟 Object Versioning，isLive: true 代表只刪現行版本；也可另外加規則清理舊版（非必需）。
