#! /bin/sh
# requires libguestfs-tools to be installed.
# This script is designed to be run inside the ProxMox VE host environment.

while getopts u:n:i: flag
do
    case "${flag}" in
        u) arg_cloud_init_url=${OPTARG};;
        n) arg_template_name=${OPTARG};;
        i) arg_template_id=${OPTARG};;
    esac
done

if [ -z "$arg_cloud_init_url" ] || [ -z "$arg_template_name" ] || [ -z "$arg_template_id" ]; then
    echo 'Arguments missing -u (Cloud-init image URL to Download), -n (Proxmox Template Name) or -i (Proxmox ID for Template)' >&2
    exit 1
fi

build_vm_id=$arg_template_id
install_dir='/VMTemplates/ISO/template/cloud-init/'
creator='Trevor Squillario <Trevor_Squillario@Dell.com>'

# Create this file and add your SSH keys 1 per line
keyfile=${install_dir}keyfile
cloud_img_url=$arg_cloud_init_url
# Ubuntu 24.04
#cloud_img_url='https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img'
# Rocky 9
#cloud_img_url='https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2'


# Enter the additional packages you would like in your template.
package_list='cloud-init,qemu-guest-agent,curl,wget,tree,tmux,git,vim,bash-completion'

# What storage location on your PVE node do you want to use for the template? (zfs-mirror, local-lvm, local, etc.)
storage_location='VMStorage'
resource_pool='UserVMs'

# VM Options
#searchdomain='ENTER-SEARCH-DOMAIN-HERE'

# Username for accessing the image
cloud_init_user='trevor'

# Default setting is the most common
scsihw='virtio-scsi-pci'

# Set template name and image file name on disk. We want to separate the source image from the custom image we are building
template_name=$arg_template_name
source_image_name=${cloud_img_url##*/}
image_extension="${source_image_name##*.}"
image_name="${template_name}.${image_extension}"

# Memory and CPU cores. These are overridden with image deployments or through the PVE interface.
vm_mem='2048'
vm_cores='2'
vm_disk_size='40G'

# Where to store the build-info file in the template for easy identification.
build_info_file_location='/etc/release-build-info'
cloud_init_snippets_location='/var/lib/vz/snippets'

source_image_path=${install_dir}${source_image_name}
image_path=${install_dir}${image_name}

# Grab latest cloud-init image for your selected image
if [ ! -f $source_image_path ]; then
    echo "Downloading cloud-init image to ${source_image_path}"
    wget ${cloud_img_url} -O "${source_image_path}"
else
    echo "${source_image_path} found. Delete file to redownload"
fi

# Clean up any previous build
rm $image_path
rm ${install_dir}build-info

# Copy source image to image we are going to customize
echo "Copy ${source_image_path} to ${image_path}"
cp $source_image_path $image_path

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
virt-customize --timezone "America/Chicago" -a ${image_path}
# SELinux
virt-customize --selinux-relabel -a ${image_path}
virt-customize --run-command ' sed -i "s/^SELINUX=.*/SELINUX=disabled/g" /etc/selinux/config' -a ${image_path}
# Add users
virt-customize --run-command "useradd -m -s /bin/bash oseadmin" -a ${image_path} \
--run-command "usermod -a -G sudo oseadmin"  -a ${image_path} \
--run-command "usermod -a -G wheel oseadmin"  -a ${image_path}
virt-customize --password "oseadmin:file:/root/secrets/passwd_oseadmin" -a ${image_path}
virt-sysprep --root-password "file:/root/secrets/passwd_root" -a ${image_path} 
#--ssh-inject "oseadmin:file:/root/secrets/oseadmin.pub" -a ${image_path}

# SSH config
if [ ! -d $cloud_init_snippets_location ]; then
    mkdir $cloud_init_snippets_location
fi
cp proxmox-create-cloud-init-image.yaml $cloud_init_snippets_location/
qm set ${build_vm_id} --cicustom "user=local:snippets/proxmox-create-cloud-init-image.yaml"

# Build image
qm destroy ${build_vm_id}
qm create ${build_vm_id} --pool ${resource_pool} --memory ${vm_mem} --cpu "cputype=host" --cores ${vm_cores} --net0 "virtio,bridge=vmbr0,mtu=1200" --name ${template_name}
qm importdisk ${build_vm_id} $image_path ${storage_location}
qm set ${build_vm_id} --scsihw ${scsihw} --virtio0 "${storage_location}:vm-${build_vm_id}-disk-0,iothread=1"
qm set ${build_vm_id} --ide2 ${storage_location}:cloudinit
qm set ${build_vm_id} --efidisk0 ${storage_location}:0 --bios ovmf
qm set ${build_vm_id} --ipconfig0 ip=dhcp --ostype l26 --sshkeys ${keyfile} --ciuser ${cloud_init_user} #--cipassword "" # --searchdomain ${searchdomain}
qm set ${build_vm_id} --boot c --bootdisk virtio0
qm set ${build_vm_id} --agent enabled=1
# Allow Proxmox GUI console access
qm set ${build_vm_id} --serial0 socket --vga serial0
# Resize disk
qm resize ${build_vm_id} virtio0 $vm_disk_size
# Convert to template
qm template ${build_vm_id}
