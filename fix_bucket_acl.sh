#!/bin/bash
# 檢查並移除 GCS bucket 中的 allUsers 公開讀取權限
# 用法：./fix_bucket_acl.sh <PROJECT_ID> [--dry-run]

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "用法：$0 <PROJECT_ID> [--dry-run]"
  exit 1
fi

PROJECT_ID="$1"
DRY_RUN=false
if [ "${2-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

echo "🚀 專案：$PROJECT_ID"
echo "🔧 模式：$([ "$DRY_RUN" = true ] && echo DRY-RUN || echo APPLY)"
echo "=============================================="

# 統計/報表
scanned=0
affected=0
declare -a modified_buckets   # 真的有動到
declare -a would_change_buckets  # 乾跑時會動到

# 列出該專案的所有 bucket
buckets=$(gsutil ls -p "$PROJECT_ID" || true)

if [ -z "$buckets" ]; then
  echo "（沒有找到任何 bucket）"
  exit 0
fi

for bucket in $buckets; do
  scanned=$((scanned+1))
  echo "🔍 檢查 $bucket"

  # 抓 IAM 設定；若取不到就跳過
  if ! iam=$(gsutil iam get "$bucket" 2>/dev/null); then
    echo "   ⚠️  讀取 IAM 失敗，略過"
    continue
  fi

  found_obj_viewer=false
  found_legacy_reader=false

  if echo "$iam" | grep -q 'allUsers.*roles/storage.objectViewer'; then
    found_obj_viewer=true
  fi
  if echo "$iam" | grep -q 'allUsers.*roles/storage.legacyBucketReader'; then
    found_legacy_reader=true
  fi

  if [ "$found_obj_viewer" = false ] && [ "$found_legacy_reader" = false ]; then
    echo "   ✅ 無公開 allUsers 權限"
    continue
  fi

  affected=$((affected+1))

  if [ "$DRY_RUN" = true ]; then
    echo "   📝（dry-run）將移除："
    [ "$found_obj_viewer" = true ] && echo "     - allUsers:objectViewer"
    [ "$found_legacy_reader" = true ] && echo "     - allUsers:legacyBucketReader"
    would_change_buckets+=("$bucket")
  else
    [ "$found_obj_viewer" = true ] && {
      echo "   ➖ 移除 allUsers:objectViewer"
      gsutil iam ch -d allUsers:objectViewer "$bucket"
    }
    [ "$found_legacy_reader" = true ] && {
      echo "   ➖ 移除 allUsers:legacyBucketReader"
      gsutil iam ch -d allUsers:legacyBucketReader "$bucket"
    }
    modified_buckets+=("$bucket")
    echo "   ✅ 已處理"
  fi
done

echo "=============================================="
echo "📊 總掃描 bucket：$scanned"
echo "📌 發現有公開權限的 bucket：$affected"

if [ "$DRY_RUN" = true ]; then
  if [ ${#would_change_buckets[@]} -eq 0 ]; then
    echo "✅（dry-run）沒有需要修改的 bucket"
  else
    echo "🧾（dry-run）以下 bucket 會被修改："
    for b in "${would_change_buckets[@]}"; do
      echo " - $b"
    done
  fi
else
  if [ ${#modified_buckets[@]} -eq 0 ]; then
    echo "✅ 沒有任何 bucket 被修改"
  else
    echo "🧾 已修改的 bucket："
    for b in "${modified_buckets[@]}"; do
      echo " - $b"
    done
  fi
fi
