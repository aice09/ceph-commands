```
for ubuntu always do activate root
sudo passwd root
sudo sed -i.bak -e 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin yes/' \
                -e 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication yes/' \
                /etc/ssh/sshd_config
sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh


to restore sshd_config
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart ssh

to create keygen
ssh-keygen -t ed25519 -C "bastion-key" -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@k8s-master4
```
