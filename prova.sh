docker manifest create \
mastrogeppetto/nglab-desktop-multiarch:latest \
--amend mastrogeppetto/nglab-desktop-multiarch_amd64:latest \
--amend mastrogeppetto/nglab-desktop-multiarch_arm64:latest
