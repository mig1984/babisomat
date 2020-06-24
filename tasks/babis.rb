require_relative '../logger'
require 'yaml'


def load_items(path)
  e = Dir.open(path).entries
  e.delete '.'
  e.delete '..'
  e.delete 'durations.yml'

  durations = {}
  if File.exists?("#{path}/durations.yml")
    durations = YAML::load_file("#{path}/durations.yml")
  end
  change = false
  e.each do |x|
    if ! durations[x]
      out = ` ffprobe -i \"#{path}/#{x}\" -show_entries format=duration -v quiet -of csv=\"p=0\" `
      raise "error ffprobe" unless $?.success?
      durations[x] = out.to_f*1000
      change = true
    end
  end
  if change
    File.open("#{path}/durations.yml", "w+") {|f| f.puts durations.to_yaml }
  end

  durations
end

desc "Generate aplaus"
task :generate_aplaus do

  # TODO: generovat tez next frame

  #frame = Time.now.to_i/60/2
  frame = 'x'

  # sliby
  durations = load_items("audio/sliby")
  shuf = durations.keys.shuffle!
  cau = shuf.delete('cau.ogg')
  silence05 = shuf.delete 'silence05.ogg'
  silence1 = shuf.delete 'silence1.ogg'
  silence15 = shuf.delete 'silence15.ogg'
  silence2 = shuf.delete 'silence2.ogg'
  silence25 = shuf.delete 'silence25.ogg'
  silence3 = shuf.delete 'silence3.ogg'
  silence35 = shuf.delete 'silence35.ogg'
  silence4 = shuf.delete 'silence4.ogg'
  silence5 = shuf.delete 'silence5.ogg'
  silence6 = shuf.delete 'silence6.ogg'
  silence7 = shuf.delete 'silence7.ogg'
  silence8 = shuf.delete 'silence8.ogg'
  silence9 = shuf.delete 'silence9.ogg'
  silence10 = shuf.delete 'silence10.ogg'

  aplaus = []
  seq = []

  seq << cau
  aplaus << false

  shuf.each do |x|
    seq << x
    aplaus << false
    if rand(15)==0
      if rand(2)==0
        seq << silence3
      else
        seq << silence1
      end
      aplaus << 'petlidi.mp3'
    elsif rand(20)==0
      seq << false
      aplaus << 'kasel.mp3'
    elsif rand(10)==0
      seq << silence7
      aplaus << 'smich.mp3'
    elsif rand(12)==0
      seq << silence6
      aplaus << 'smich2.mp3'
    #elsif rand(15)==0
    #  seq << false
    #  aplaus << 'scream.mp3'
    end
  end

  #c = "ffmpeg -i 'concat:audio/cau.ogg"
  #shuf.each { |x| c << "|audio/sliby/#{x}" }
  #c << "' audio-generated/#{frame}-sliby.ogg"
  #$log.debug "running: #{c}"
  #system(c) or raise "error running #{c}"

  #pauza pro smich -> jako je cau.ogg tak silence
  #cau.ogg i silence davat do sliby, sestavit to do shuffle

#  ffmpeg -i cau.ogg -i 1.ogg -i 0.ogg -filter_complex "[1]adelay=2000|2000[a]; [2]adelay=4000|4000[b]; [0][a][b]amix=inputs=3"  out.ogg

  c = "ffmpeg "
  fc = "-filter_complex \""
  num = 0
  pos = 0
  seq.each do |x|
    if x
      c << "-i \"audio/sliby/#{x}\" "
      fc << "[#{num}]adelay=#{pos}|#{pos}[i#{num}]; "
      num += 1
      pos += durations[x]
    end
  end
  num.times do |i|
    fc << "[i#{i}]"
  end
  fc << "amix=inputs=#{num} "
  fc << "\" "
  c << fc
  c << "audio-generated/#{frame}-sliby-babis.ogg"
  $log.debug "running: #{c}"
  system(c) or raise "error running #{c}"

  # aplaus
  c = "ffmpeg "
  fc = "-filter_complex \""
  num = 0
  pos = 0
  seq.each do |x|
    if which=aplaus.shift
      c << "-i \"audio/aplaus/#{which}\" "
      fc << "[#{num}]adelay=#{pos}|#{pos}[i#{num}]; "
      num += 1
    end
    if x
      pos += durations[x]
    end
  end
  num.times do |i|
    fc << "[i#{i}]"
  end
  fc << "amix=inputs=#{num} "
  fc << "\" "
  c << fc
  c << "audio-generated/#{frame}-sliby-aplaus.ogg"
  $log.debug "running: #{c}"
  system(c) or raise "error running #{c}"

  # mix together
  c = "ffmpeg -i audio-generated/#{frame}-sliby-babis.ogg -i audio-generated/#{frame}-sliby-aplaus.ogg -filter_complex \"[0][1]amix=inputs=2,loudnorm,volume=8dB\" audio-generated/#{frame}-sliby.ogg "
  $log.debug "running: #{c}"
  system(c) or raise "error running #{c}"

end

desc "Delete old babis"
task :delete_old_babis do

  def file_age(name)
    (Time.now - File.ctime(name))
  end

  Dir.open("babis-generated").each do |filename|
    if filename!='.' && filename!='..' && file_age("babis-generated/#{filename}") > 60*60
      File.delete("babis-generated/#{filename}")
    end
  end

end
