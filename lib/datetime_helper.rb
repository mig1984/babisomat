class DatetimeHelper

   class << self

  # use b3form czdatetime field type instead
  def time2str(ts)
		ts.strftime('%d.%m.%Y %H:%M')
	end
	
  # use b3form cz2datetime instead
	def str2time(str)
		str=~/^\s*((\d+)\s*\.\s*(\d+)\s*\.(\s*(\d+))?)?(\s+(\d+)\s*:\s*(\d+)(\s*:\s*(\d+))?)?\s*$/
		now = Time.now
		raise ArgumentError.new('str2timestamp: Bad input') if !$1
		day = $2 || now.day
		month = $3 || now.month
		year = $5 || now.year
		if $6
			hour = $7
			min = $8
			sec = $10
		else
			hour = 0
			min = 0
			sec = 0
		end
		Time.local(year.to_i,month.to_i,day.to_i,hour.to_i,min.to_i,sec.to_i)
	end
	
   def format_date(time,lang='cz')
      ret = ''
      if time
         now = Time.now
         diff = now.to_i - time.to_i
         ago = (now.to_i - time.to_i)/3600/24
         if lang == 'cz'
            if ago>=0 && ago < 3
               ret << ['dnes','včera','předevčírem'][ago]
            elsif ago>=0 && ago <= 6
               ret << ['v neděli', 'v pondělí', 'v úterý', 've středu', 've čtvrtek', 'v pátek', 'v sobotu'][time.strftime('%w').to_i]
            else
               ret << time.strftime('%d.%m.%Y')
            end
            if time.strftime("%H:%M") != "00:00"
               ret << " " + %w(v v ve ve ve v v v v v v v ve ve ve v v v v v ve ve ve ve)[time.strftime('%H').to_i]
               ret << " "+time.strftime('%H:%M').gsub(/^0/,'')
            end
         else
            if ago>=0 && ago < 2
               ret << ['today','yesterday'][ago]
            elsif ago>=0 && ago <= 6
               ret << ['on Sunday', 'on Monday', 'on Tuesday', 'on Wednesday', 'on Thursday', 'on Friday', 'on Saturday'][time.strftime('%w').to_i]
            else
               ret << time.strftime('%b %d %Y')
            end
            if time.strftime("%H:%M") != "00:00"
               ret << " at "+time.strftime('%I')+time.strftime('%p').downcase
            end
         end
      end
      ret
   end
   
   end

end

if __FILE__ == $0
	x = DatetimeHelper::str2time('3. 4. 2015 13:33:45')
	puts x.to_s
	puts DatetimeHelper::time2str(x)
	puts DatetimeHelper::format_date(x)
	puts DatetimeHelper::format_date(Time.now)
end
