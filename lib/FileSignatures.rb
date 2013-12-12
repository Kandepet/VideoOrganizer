require 'zlib'

module Signature

   def self.crc(filename)
      ret_crc32 = 0        # CRC initial value.
      max_buf_size = 8192  #buffer of 8 * 1024 byte.

      buf = [""].pack('A8192')
      File.open(filename,'rb') do |fp|
         while fp.read(max_buf_size, buf)
            ret_crc32 = Zlib.crc32(buf, ret_crc32)
         end
      end

      #puts " CRC32 for [ #{filename} ] IS [ #{ret_crc32} ] "
      return ret_crc32
   end


   ##
   # A Ruby implementation of the Adler-32 checksum algorithm,
   # which uses Ruby's own Zlib.adler32 class method.
   #
   # This Ruby implementation is a port of the Python adler32
   # implementation found in the pysync project. The Python reference
   # implementation, itself, was a port from zlib's adler32.c file.
   #
   # @see http://zlib.net/
   # @see http://freshmeat.net/projects/pysync/
   #
   class Adler32

      # largest prime smaller than 65536
      BASE = 65521
      # largest n such that 255n(n+1)/2 + (n+1)(BASE-1) <= 2^32-1
      NMAX = 5552
      # default initial s1 offset
      OFFS = 1

      ##
      # @param data (String) initial block of data to digest.
      #
      def initialize(data='')
         value = Zlib.adler32(data, OFFS)
         @s2, @s1 = (value >> 16) & 0xffff, value & 0xffff
         @count = data.length
      end

      ##
      # Adds another block of data to digest.
      #
      # @param data (String) block of data to digest.
      # @return (Fixnum) the updated digest.
      #
      def update(data)
         value = Zlib.adler32(data, (@s2 << 16) | @s1)
         @s2, @s1 = (value >> 16) & 0xffff, value & 0xffff
         @count = @count + data.length
         return self.digest
      end

      ##
      # @param x1 (Byte)
      # @param xn (Byte)
      # @return (Fixnum) the updated digest.
      #
      def rotate(x1, xn)
         @s1 = (@s1 - x1 + xn) % BASE
         @s2 = (@s2 - (@count * x1) + @s1 - OFFS) % BASE
         return self.digest
      end

      ##
      # @param b (Byte)
      # @return (Fixnum) the updated digest.
      #
      def rollin(b)
         @s1 = (@s1 + b) % BASE
         @s2 = (@s2 + @s1) % BASE
         @count = @count + 1
         return self.digest
      end

      ##
      # @param b (Byte)
      # @return (Fixnum) the updated digest.
      #
      def rollout(b)
         @s1 = (@s1 - b) % BASE
         @s2 = (@s2 - @count * b) % BASE
         @count = @count - 1
         return self.digest
      end

      ##
      # @return (Fixnum) the current Adler32 digest value.
      #
      def digest
         return (@s2 << 16) | @s1
      end
   end

end
