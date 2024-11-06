# 2024-11-06 Setup cloud vision on OBF, OPF, OPFF containers

as root in the obf, opf, opff containers:

```bash
export SERVICE=obf
cd /etc/systemd/system
sudo ln -s /srv/$SERVICE/conf/systemd/cloud_vision_ocr@.service cloud_vision_ocr@$SERVICE.service
sudo systemctl daemon-reload
sudo systemctl start cloud_vision_ocr@$SERVICE
sudo systemctl status cloud_vision_ocr@$SERVICE
```

Also added to the end of [2024-04-26 New install of OBF on OFF2 with new generic code](./2024-04-26-off2-obf-new-install.md)