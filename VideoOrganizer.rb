#!/usr/bin/env ruby

require 'find'
require 'exifr'
require 'mini_exiftool'
require "fileutils"
require 'optparse'
require 'pp'
require 'zlib'
require './lib/DirWalker'
require './lib/FileSignatures'



VIDEO_EXTENSIONS = [".MOV", ".mov", ".MTS", ".mts", ".MP4", ".mp4"]

class FileOrganizer
   OTHER_DIR = "Other"

   # dup modes
   IGNORE_DUPS = 0
   SKIP_DUPS   = 1
   MARK_DUPS   = 2
   NOT_A_DUP   = -1

   def initialize source_path, dest_dir, threshold
      @source_path = source_path
      @dest_dir = dest_dir
      @threshold = threshold

      #verbose "Threshold: #{@threshold}"
      #verbose "Processing:  #{@source_path}"
   end

   def ext
      File.extname(@source_path.downcase)
   end

   def is_video?
      VIDEO_EXTENSIONS.include? ext
   end

   def timestamp(file = nil)
      file = @source_path if file == nil
      #verbose "Scanning #{file}"
      exif_file = MiniExiftool.new(file)
      if (ext == ".mov") && exif_file['CreateDate']
         #verbose "Original CreateDate: #{exif_file['CreateDate']}"
         return exif_file['CreateDate']
      elsif (ext == ".mov" || ext == ".mts") && exif_file['DateTimeOriginal']
         #verbose "Original Date/Time: #{exif_file['DateTimeOriginal']}"
         return exif_file['DateTimeOriginal']
      elsif (ext == ".mp4") && exif_file["Year"]
         #verbose "Original Year: #{exif_file['Year']}"
         return DateTime.parse(exif_file['Year'])
      else
         #return File.new(@source_path).ctime
         return File.new(file).ctime
      end
   end

   def original_name
      File.basename @source_path
   end

   def original_name_without_ext
      original_name.chomp(File.extname(original_name) )
   end

   def path_with_timestamp_without_ext
      file_timestamp = timestamp
      if is_video?
         #return "#{@dest_dir}#{File::SEPARATOR}#{file_timestamp.year}#{File::SEPARATOR}#{file_timestamp.strftime("%b")}#{File::SEPARATOR}#{file_timestamp.strftime("%d - %a")}#{File::SEPARATOR}#{file_timestamp.strftime("%I:%M:%S %p")} - #{original_name_without_ext}"
         return "#{@dest_dir}#{File::SEPARATOR}#{file_timestamp.year}#{File::SEPARATOR}#{file_timestamp.strftime("%b")}#{File::SEPARATOR}#{file_timestamp.strftime("%d-%a")}#{File::SEPARATOR}#{file_timestamp.strftime("%I-%M-%S-%p")}"
      else
         return "#{@dest_dir}#{File::SEPARATOR}#{OTHER_DIR}#{File::SEPARATOR}#{original_name_without_ext}"
      end
   end

   def path_with_timestamp(append = "")
      return "#{path_with_timestamp_without_ext}#{append}#{ext}"
   end

   def file_with_same_name_exists?(path)
      exists = File.exists? path
      #verbose "File #{path} exists = #{exists}"
      return exists
   end

   # Returns (is_duplicate?, path)
   def get_path(mode, signature, append = "")
      path = path_with_timestamp(append)
      count = 1
      while(file_with_same_name_exists?(path))
         #dest_sig = Digest::MD5.file(path)
         #dest_sig = Signature.crc(path)
         dest_sig = Signature.crc(path)
         if (mode != IGNORE_DUPS) && (signature == dest_sig)
            #puts "SKIPPING : #{@source_path} & #{path} have same signature: #{dest_sig}."
            #puts " "
            return true, path
         else
            #verbose "File #{path} exists, incrementing"
            path = path_with_timestamp("#{append}-COPY_#{count}")
            count += 1
         end
      end

      return false, path
   end

   def copy(mode)
      if !is_video?
         verbose "IGNORING: UNKNOWN FORMAT: #{@source_path}"
         return
      end

      signature = Signature.crc(@source_path)
      duplicate, dest_path_v = get_path(mode, signature)

      # Figure out the path to copy to.
      if mode == IGNORE_DUPS
         verbose "COPYING TO: #{dest_path_v}"
         # Don't care about dups, copy the file.
         #dest_path_v = dest_path(IGNORE_DUPS)
         #duplicate, dest_path_v = get_path(IGNORE_DUPS)
      else
         #signature = Digest::MD5.file(@source_path)
         #signature = Signature.crc(@source_path)
         #puts "#{@source_path} => #{signature}"

         #dest_path_v = is_duplicate?(signature)
         #duplicate, dest_path_v = get_path(signature)
         if duplicate == true
            if mode == SKIP_DUPS
               # Skipping it
               verbose "SKIPPING: FOUND DUPLICATE: #{dest_path_v}"
               return
            elsif mode == MARK_DUPS

               #verbose "WILL MARK AS DUP"
               # Need to find a suitable name for the dup
               append = "-DUPLICATE_OF-#{File.basename(dest_path_v)}"

               #verbose "Appending: #{append}"
               # Just get the new file name, ignoring dups
               # I already know there is a dupe. I just want a new path created
               # with my append string.
               #dest_path_v = dest_path(MARK_DUPS, append)
               duplicate, dest_path_v = get_path(IGNORE_DUPS, signature, append)
               verbose "COPYING DUPLICATE TO: #{dest_path_v}"
            end
         else
            verbose "COPYING TO: #{dest_path_v}"
         end
      end

      #irrespective of if it is a dup or not, save the fingerprint.
      # change the path in the hash to the file's new path
      FileUtils.mkdir_p File.dirname dest_path_v
      FileUtils.cp  @source_path, dest_path_v
   end
end

class VideoOrganizer

   def organize options
      #process the new files
      RecursiveDirWalker.new(options[:input_dir]).walk do |file|
         FileOrganizer.new(file, options[:output_dir], options[:threshold]).copy(options[:mode])
      end

   end

end

$options = {}
option_parser = OptionParser.new do |o|
   o.on('-d [0/1/2]', "Enable duplicate detection. The mode signifies the action to take",
        "0 = No duplicate detection. Copy all files",
        "1 = Detect and skip all duplicates",
        "2 = Detect and mark duplicates",
        "", " ") { |b|
           if b == nil
              b = 0
           end

           b = b.to_i

           if ((b < 0) || (b > 2))
              puts "ERROR: unknown duplicate detection mode: #{b}"
              puts option_parser
              exit
           end

           $options[:mode] = b
        }
   o.on('-i INPUT_DIR') { |path| $options[:input_dir] = path }
   o.on('-o OUTPUT_DIR') { |path| $options[:output_dir] = path }
   o.on('-h', "Help") { puts o; exit }
   o.on('-v', "Verbose") { |b| $options[:verbose] = b }
end

begin
   option_parser.parse!
rescue OptionParser::ParseError
   puts option_parser
   exit
end

unless $options[:input_dir] && $options[:output_dir]
   puts "ERROR: Both INPUT & OUTPUT directory is needed"
   puts option_parser
   exit;
end

def verbose(str)
   if $options[:verbose]
      puts str
   end
end


#remove any trailing /
$options[:input_dir] = $options[:input_dir].sub(/(#{File::SEPARATOR})+$/,'')
$options[:output_dir] = $options[:output_dir].sub(/(#{File::SEPARATOR})+$/,'')

organizer = VideoOrganizer.new
organizer.organize $options

