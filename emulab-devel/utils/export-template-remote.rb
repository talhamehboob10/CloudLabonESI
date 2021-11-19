#!/usr/bin/ruby
#
# Copyright (c) 2012-2014 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

$: << File.dirname(__FILE__)
require 'GrubConf'

def command?(name)
  `which #{name}`
  $?.success?
end

#TODO: Verify arch

class EmulabExport
    attr_accessor :identity
    attr_accessor :fssize

    def initialize()
        @workdir = File.dirname(File.expand_path $0) 
    end

    def finalize()
        system("rm /tmp/emulab-image >/dev/null 2>&1");
        system("rm " + @workdir + "/kernel >/dev/null 2>&1");
        system("rm " + @workdir + "/initrd >/dev/null 2>&1");
        system("rm " + @workdir + "/bootopts >/dev/null 2>&1");
        system("rm " + @workdir + "/ec2-ami-tools.zip >/dev/null 2>&1");
        system("rm -Rf " + @workdir + "/ec2-ami-tools-1.4.0.9 >/dev/null 2>&1");
    end

    def create_image()
        raise "Failed fetching ec2-utils" unless
            system("wget http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools-1.4.0.9.zip" + 
            " -O " + @workdir + "/ec2-ami-tools.zip")
        raise "Failed unzippinging ec2-utils" unless
            system("unzip " + @workdir +"/ec2-ami-tools.zip")

        $:.unshift(Dir.pwd + "/ec2-ami-tools-1.4.0.9/lib/")
        require 'ec2/platform/current'

        excludes = ['/tmp/emulab-image', '/dev', '/media', '/mnt',
            '/proc', '/sys', '/', '/proc/sys/fs/binfmt_misc', '/dev/pts',
            '/var/lib/cloud/sem', @workdir]

       
        image = EC2::Platform::Current::Image.new("/",
                        "/tmp/emulab-image",
                        @fssize+800,
                        excludes,
                        [],
                        false,
                        nil,
                        true)
        image.make
    end

    def check_prereqs()
        raise "No unzip found. Please install unzip" unless
            command?("unzip")

        # Remove any previous image tries
        system("rm /tmp/emulab-image >/dev/null 2>&1");
        system("rm " + @workdir + "/kernel >/dev/null 2>&1");
        system("rm " + @workdir + "/initrd >/dev/null 2>&1");
        system("rm " + @workdir + "/bootopts >/dev/null 2>&1");
        system("rm " + @workdir + "/ec2-ami-tools.zip >/dev/null 2>&1");
        system("rm -Rf " + @workdir + "/ec2-ami-tools-1.4.0.9 >/dev/null 2>&1");


        # TODO this probably needs to be more elaborate
        @fssize = Integer(`df -PBM --total / | grep total | awk '{gsub(/M$/,"",$3);print $3}'`)
        empsize = Integer(`df -PBM --total / | grep total | awk '{gsub(/M$/,"",$4);print $4}'`)
        puts "Disk on / has " + @fssize.to_s + "M of data and " +
            empsize.to_s + "M free space"
        raise "Not enough disk space to create image" if empsize < @fssize * 1.7
        
    end
    
    # Look for a menu.lst or grub.cfg and run the parser on that to find kern
    def find_grub_cfgs()
        cfgs = []
        pgrub2 = ["/boot/grub2/grub.cfg", "/boot/grub/grub.cfg",
                    "/grub/grub.cfg", "/grub2/grub.cfg"]

        pgrub2.each do |grub_config|
            if File.exists?(grub_config)
                cfg = Grub2ConfigFile.new(grub_config)
                cfg.parse()
                if cfg.images.length > 0
                    cfgs << cfg
                end
            end
        end
                    
        pgrub1 = ["/boot/grub/menu.lst", "/boot/grub/grub.conf",
                    "/grub/menu.lst", "/grub/grub.conf"]

        pgrub1.each do |grub_config|
            if File.exists?(grub_config)
                cfg = Grub1ConfigFile.new(grub_config)
                cfg.parse()
                if cfg.images.length > 0
                    cfgs << cfg
                end
            end
        end

        return cfgs
    end

    def get_kernel()
        version = `uname -r`.chomp

        pkernels = []
        pkernels << "/boot/vmlinuz-" + version
        pkernels << "/vmlinuz-" + version
        pkernels << "/boot/kernel-" + version
        pkernels << "/boot/vmlinux-" + version
        pkernels << "/vmlinux-" + version

        pkernels << "/boot/vmlinuz-" + version + ".img"
        pkernels << "/vmlinuz-" + version + ".img"
        pkernels << "/boot/kernel-" + version + ".img"
        pkernels << "/boot/vmlinux-" + version + ".img"
        pkernels << "/vmlinux-" + version + ".img"

        # Well, this should cover MOST of the cases. 
        # Parsing the grub config is really hard because grub 2 uses a script
        # and not a menu.lst like the legacy one
        pinitrd = []
        pinitrd << "/boot/initrd.img-" + version
        pinitrd << "/boot/initrd-" + version + ".img"
        pinitrd << "/boot/initrd-" + version
        pinitrd << "/boot/initramfs-" + version + ".img"
        pinitrd << "/boot/initramfs-genkernel-" + version

        kernelfound = false
        pkernels.each do |kernel|
            if File.exists?(kernel)
                kernelfound = true
                raise "Couldn't copy kernel" unless
                    system("cp " + kernel + " " + @workdir + "/kernel")
                break
            end
        end

        initrdfound = false
        pinitrd.each do |initrd|
            if File.exists?(initrd)
                initrdfound = true
                raise "Couldn't copy initrd" unless
                    system("cp " + initrd + " " + @workdir + "/initrd")
                break
            end
        end

        if kernelfound == false or initrdfound == false
            cfgs = find_grub_cfgs()
           
            catch :donekernelsearch do
                cfgs.each do |cfg|
                    cfg.images.each do |image|
                        if image.kernel and image.initrd and
                            (image.title.include? version or
                            image.kernel.include? version or
                            image.initrd.include? version)

                            if File.exists?(image.kernel) and File.exists?(image.initrd)
                                raise "Couldn't copy kernel from " + image.kernel unless
                                    system("cp " + image.kernel + " " + @workdir + "/kernel")
                                raise "Couldn't copy initrd from " + image.initrd unless
                                    system("cp " + image.initrd + " " + @workdir + "/initrd")
                                kernelfound = initrdfound = true
                                throw :donekernelsearch
                            end
                        end
                    end
                end
            end #And she's buying a stairway to heaven
        end
        raise "Couldn't find your kernel and initrd properly" unless kernelfound and initrdfound

    end


    def get_bootopts()
        raise "Couldn't get bootopts" unless
            system("cat /proc/cmdline > " + @workdir + "/bootopts") 
    end

    def gen_tar()
        puts "Running:  tar -cvzf emulab.tar.gz kernel initrd" +
            " bootopts -C /tmp/ emulab-image 2>&1"
        raise "Couldn't tar" unless
            system("tar -cvzf emulab.tar.gz kernel initrd" +
            " bootopts -C /tmp/ emulab-image 2>&1")
    end

end


if __FILE__ == $0
    raise 'Must run as root' unless Process.uid == 0

    retval = 0
    begin
        ex = EmulabExport.new()
        ex.check_prereqs
        ex.get_kernel
        ex.get_bootopts
        ex.create_image
        ex.gen_tar
    rescue Exception => e
        print "Error while creating an image: \n"
        puts e.message
        puts e.backtrace.join("\n")
        retval = 1
    ensure
        ex.finalize()        
    end
    exit retval
end

