#!/usr/bin/ruby
#
# Copyright (c) 2013 University of Utah and the Flux Group.
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
# Basic menu.lst and grub.conf parsing

class GrubImage
    attr_accessor :title, :kernel, :initrd, :root
    attr_accessor :lines, :kernel_args

    def print()
        puts "Title: " + title
        puts "kernel: " + kernel if kernel
        puts "kernel_args: " + kernel_args if kernel_args
        puts "root: " + root if root
        puts "initrd: " + initrd if initrd
    end

    def initialize(title, lines)
        raise "Title required for GrubImage" if title == nil
        @title = title
        @lines = lines
        parse()
    end

end

class Grub1Image < GrubImage
    def parse
        @lines.each do |line|
            command, args = line.split(nil,2)
            case command
            when "kernel"
                @kernel, @kernel_args = args.split(nil, 2)
            when "initrd"
                @initrd = args
            when "root"
                @root = args
            else
                #puts "Ignored " + line
            end
        end
    end
end


class Grub2Image < GrubImage

    def parse
        @lines.each do |line|
            command, args = line.split(nil,2)
            case command
            when "linux"
                @kernel, @kernel_args = args.split(nil, 2)
            when "initrd"
                @initrd = args
            when "set"
                args.strip!
                subcommand, args = args.split("=",2)
                case subcommand
                when "root"
                    @root = args
                else
                    puts "Ignored " + line
                end
            else
                #puts "Ignored " + line
            end
        end
    end
end


class GrubConfigFile
    attr_accessor :images

    def initialize filename
        @lines = IO.readlines(filename)
        @images = []
    end

    def add_image image
        @images << image
    end
    def print
        images.each{|img| img.print}
    end

end


class Grub1ConfigFile < GrubConfigFile
    def initialize filename
        super filename
    end

    def parse
        image_lines = nil
        image_title = nil
        @lines.each do |line|
            line.strip!
            next if line.length == 0
            next if line.start_with?("#")
            
            if m = line.start_with?("title")
                if image_title
                    self.add_image(Grub1Image.new(image_title, image_lines))
                end
                
                image_lines = []
                image_title = line.split(nil, 2)[1]
                next
            end

            if image_title then
                image_lines << line
                next
            end

            #Ignore everything else
        end
        if image_title
            self.add_image(Grub1Image.new(image_title, image_lines))
        end


    end
end

class Grub2ConfigFile < GrubConfigFile
    def initialize filename
        super filename
    end


    def parse
        in_function = false
        image_lines = nil
        image_title = nil
        level = 0
        @lines.each do |line|
            line.strip!
            next if line.length == 0
            next if line.start_with?("#")
            
            # throw out functions
            if line.start_with?("function") then
                in_function = true
                next
            end
            if in_function then
                in_function = false if line.start_with?("}")
                next
            end

            if m = line.match('^menuentry ["\'](.*)["\'] (.*)\{') then
                raise "nested menuentry" if image_title != nil
                image_lines = []
                image_title = m[1]
                next
            end
            
            if line.start_with?("submenu") then
                level = level + 1
                next
            end
            
            if line.start_with?("}") then
                if image_title == nil then
                    if level > 0
                        level = level - 1
                        next
                    else
                        raise "not closing anything"
                    end
                else
                    self.add_image(Grub2Image.new(image_title, image_lines))
                    image_lines = nil
                    image_title = nil
                    next
                end
            end
            
            if image_title then
                image_lines << line
                next
            end

            # Throw everything else away
            # puts "Ignoring " + line
        end
    end

end


def usage()
    puts "usage: " + File.basename(__FILE__) + " <config file> <1/2>"
end

if __FILE__ == $0
    if ARGV.length != 2
        usage()
        raise "Not enough arguments"
    end

    type = ARGV[1].to_i
    if type == 1 then
        cfg = Grub1ConfigFile.new(ARGV[0])
    elsif type == 2 then
        cfg = Grub2ConfigFile.new(ARGV[0])
    else
        usage()
        raise "Type should be either 1 or 2"
    end
    cfg.parse
    cfg.print
end
