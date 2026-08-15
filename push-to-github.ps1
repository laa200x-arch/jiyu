# ============================================================
# 技遇 - 一键推送到 GitHub 并触发云端打包 (Build IPA workflow)
# ============================================================
# 前提：
#   1. 已登录 https://github.com 并创建好空仓库（不要勾选 README/.gitignore）
#      仓库地址: https://github.com/laa200x/jiyu
#   2. 仓库名不同时，把下面的 $repo 改成你的仓库名
# ============================================================
$user = "laa200x"
$repo = "jiyu"

$remote = "https://github.com/$user/$repo.git"

Write-Host "==> 添加远程仓库: $remote"
git remote remove origin 2>$null
git remote add origin $remote

Write-Host "==> 推送 main 分支"
git branch -M main
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==> 推送成功！云端打包已自动触发（也可手动触发）："
    Write-Host "    https://github.com/$user/$repo/actions"
    Write-Host "    左侧点 'Build IPA' -> 右侧 'Run workflow' 按钮"
    Write-Host ""
    Write-Host "==> 约 5-10 分钟编译完成后，在本次运行页底部 Artifacts 下载："
    Write-Host "    Jiyu-unsigned.ipa"
    Write-Host ""
    Write-Host "==> 然后用 Sideloadly (https://sideloadly.io) 安装到 iPhone："
    Write-Host "    拖入 .ipa -> 输入你的 Apple ID -> Start（iOS 16+ 需先开启开发者模式）"
} else {
    Write-Host ""
    Write-Host "==> 推送失败。常见原因与解决办法："
    Write-Host "    1. 仓库里已有 GitHub 自动生成的 README：执行"
    Write-Host "       git pull origin main --allow-unrelated-histories"
    Write-Host "       然后重新运行本脚本"
    Write-Host "    2. 账号登录弹窗：Git 会弹出 GitHub 登录窗口，按提示登录即可"
    Write-Host "    3. 仓库名不一致：打开本脚本，修改 \$repo = \"你的仓库名\""
}
