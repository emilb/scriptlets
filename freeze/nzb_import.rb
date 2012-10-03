#!/usr/bin/env ruby
=begin 
  Created by keyvan
  #newznab on irc.synirc.net

  This script is for importing a giant dump of NZB files into newznab. Be warned, it's HACKY!
  1) I expect you have downloaded a big archive full of nzbs and have extracted it.
      The directory structure should be like this:
        dump/
          MoviesHD/
            blablabla.nzb
            blablbalbalb.nzb
            fawefawef.nzb
          Music/
            blukguykg.nzb
          ... and so on ...

  2) You need to set a few constants: ADMINPATH, SCRIPTPATH, and IMPORTPATH
    You will find below right after this documentation.
    Just replace the strings with the paths that reflect your setup, instead of mine.
    
  3) Now you are ready to actually use the script. To simply begin importing do this:
    ./nzb_import.rb import
    
    BUT WAIT... The script has another feature, which is the ability to check its own status.
    To use this feature, you need to run the above command within screen, with logging enabled.
    When you enable logging in screen, it creates a file screenlog.0 in the current dir.
      
        Keep in mind, the script looks for screenlog.0 in your home directory ~/screenlog.0
        So if it doesn't work, that's why, and you can go change it in the script.
    
    Now when you run ./nzb_import.rb status from that dir, it will compare the log to the
    directories inside the import path, and tell you how much has been done vs how much is left.
  
                                      => CAUTION <= 
    There are parts of this script where I am using sudo. This may be undesirable for you!
    As such, please make sure to go in and remove the sudo. The only reason I have it there
    is because I imported with sudo because I didn't want to hassle with permissions.
  
  TODO: Make the script not suck. Add documentation to the methods.
=end

ADMINPATH  = "/var/www/newznab/www/admin" # replace with yours
SCRIPTPATH = "/var/www/newznab/misc/update_scripts" # replace with yours
IMPORTPATH = "~/dump" # replace with yours



@all = []
def fill_all(path=IMPORTPATH)
  Dir.foreach(path) do |f|
    next if ['.','..'].include?f
    if File.directory? "#{path}/#{f}"
      fill_all "#{path}/#{f}"
    elsif f.include? ".nzb"
      @all << path.match(/#{IMPORTPATH.split('/').last}\/(.*)/)[1]
      break
    end
  end
end

def get_complete
  complete = []
  `cat ~/screenlog.0 | grep complete!`.split("\n").each do |f|
    complete << f.match(/#{IMPORTPATH.split('/').last}\/(.*) is/)[1]
  end
  return complete.uniq
end

def show_diff
  @all = [] ; fill_all
  complete = get_complete
  diff = @all - complete
  if complete.any?
    puts "Completed items:"
    complete.each do |f|
      puts "    #{f}"
    end
  end
  if diff.any?
    puts "Remaining items left to import:"
    diff.each do |f|
      puts "    #{f}"
    end
  else
    puts "Import appears to have completed successfully!"
  end
end

def import!(path)
  puts %{
    There are NZB's here: #{path}\n
    Will execute:\n
      php5 #{ADMINPATH}/nzb-import.php
      php5 #{SCRIPTPATH}/update_releases.php
  }
  `cd #{ADMINPATH} && sudo php nzb-import.php #{path}`
  puts "nzb-import.php has completed, now moving on to update_releases.php"
  `cd #{SCRIPTPATH} && sudo php update_releases.php`
  puts "Import of #{path} is complete!"
end

def import?(path=IMPORTPATH)
  "Searching for NZB files in #{path}..."
  Dir.foreach(path) do |f|
    next if ['.','..'].include?f
    if File.directory? "#{path}/#{f}"
      import? "#{path}/#{f}"
    elsif f.include? ".nzb"
      import! path
      break
    end
  end
end

if ARGV[0] == "status"
  show_diff
elsif ARGV[0] == "import"
  if File.directory? IMPORTPATH
    puts "Beginning import of #{IMPORTPATH}"
    import? IMPORTPATH
  else
    puts "Invalid import path - must be a directory"
  end
else
  puts "Arguments: import, status"
end