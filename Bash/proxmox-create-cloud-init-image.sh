#! /bin/sh

# requires libguestfs-tools to be installed.
# This script is designed to be run inside the ProxMox VE host environment.

build_vm_id='1000'
install_dir='/VMTemplates/ISO/template/cloud-init/'
creator='Trevor Squillario <Trevor_Squillario@Dell.com>'

# Create this file and add your SSH keys 1 per line
keyfile=${install_dir}keyfile

cloud_img_url='https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img'
#cloud_img_url='https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2'

image_name=${cloud_img_url##*/}

# Enter the additional packages you would like in your template.
package_list='cloud-init,qemu-guest-agent,curl,wget,tree,tmux,git'

# What storage location on your PVE node do you want to use for the template? (zfs-mirror, local-lvm, local, etc.)
storage_location='VMStorage'

# VM Options
#searchdomain='ENTER-SEARCH-DOMAIN-HERE'

# Username for accessing the image
cloud_init_user='trevor'

# Default setting is the most common
scsihw='virtio-scsi-pci'

# What to name your template. This is free form with no spaces and will be used for automation/deployments.
template_name=${image_name}

# Memory and CPU cores. These are overridden with image deployments or through the PVE interface.
vm_mem='2048'
vm_cores='2'

# Where to store the build-info file in the template for easy identification.
build_info_file_location='/etc/release-build-info'
cloud_init_snippets_location='/var/lib/vz/snippets'

image_path=${install_dir}${image_name}

# Clean up any previous build
#rm $image_path
rm ${install_dir}build-info

# Grab latest cloud-init image for your selected image
if [ ! -f $image_path ]; then
    echo "Downloading cloud-init image to ${image_path}"
    wget ${cloud_img_url} -O "${image_path}"
else
    echo "${image_path} found. Delete file to redownload"
fi

# insert commands to populate the currently empty build-info file
touch ${install_dir}build-info
echo "Base Image: "${image_name} > ${install_dir}build-info
echo "Packages added at build time: "${package_list} >> ${install_dir}build-info
echo "Build date: "$(date) >> ${install_dir}build-info
echo "Build creator: "${creator} >> ${install_dir}build-info

# Customize image
virt-customize --update -a ${image_path}
virt-customize --install ${package_list} -a ${image_path}
# Add build-info to image
virt-customize --mkdir ${build_info_file_location} --copy-in ${install_dir}build-info:${build_info_file_location} -a ${image_path}
# Add /etc/inputrc for Ctrl+Up/Down Bash history search
virt-customize --copy-in inputrc:/etc -a ${image_path}
# Add users and ssh keys
#virt-sysprep --run-command"'useradd ${cloud_init_user}" --ssh-inject "${cloud_init_user}:file:/home/trevor/.ssh/id_rsa.pub" -a ${image_path}

# SSH config
if [ ! -d $cloud_init_snippets_location ]; then
    mkdir $cloud_init_snippets_location
fi
cp proxmox-create-cloud-init-image.yaml $cloud_init_snippets_location/
qm set ${build_vm_id} --cicustom "user=local:snippets/proxmox-create-cloud-init-image.yaml"

# Build image
qm destroy ${build_vm_id}
qm create ${build_vm_id} --memory ${vm_mem} --cores ${vm_cores} --net0 virtio,bridge=vmbr0 --name ${template_name}
qm importdisk ${build_vm_id} $image_path ${storage_location}
qm set ${build_vm_id} --scsihw ${scsihw} --scsi0 ${storage_location}:vm-${build_vm_id}-disk-0
qm set ${build_vm_id} --ide0 ${storage_location}:cloudinit
qm set ${build_vm_id} --ipconfig0 ip=dhcp --ostype l26 --sshkeys ${keyfile} --ciuser ${cloud_init_user} #--cipassword "calvin" # --searchdomain ${searchdomain}
qm set ${build_vm_id} --boot c --bootdisk scsi0
qm set ${build_vm_id} --agent enabled=1
qm template ${build_vm_id}
