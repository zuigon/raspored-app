
class Object
  def string?
    self.class == String
  end
end

class Time
  def to_datetime
    seconds = sec + Rational(usec, 10**6)
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, offset)
  end
end

def redrs(str, val=nil) # ~ Redis Read/Set # Set if nil, else read
  # TODO: redrs str, lambda
  x = options.R["rasapp:#{str}"].to_s
  g = (!x.nil? && !x.empty?) ? Marshal.load(x) : (options.R['rasapp:#{str}'] = (val.class == String) ? val : Marshal.dump(val); x)
end

def redr(str) # ~ Redis Read
  x = options.R["rasapp:#{str}"]
  return nil if x.nil?
  return Marshal.load(x) if x =~ /^\004/
  x
end

def redd(str, obj)
  options.R.del str
end

def load_ras
  x, d = options.R['rasapp:raspored.yml'], options.R['rasapp:raspored.yml:ts']
  if x.nil? || x.empty? || (Time.parse(d.nil? ? "1.1.2000." : d) < File.mtime('raspored.yml'))
    options.R['rasapp:raspored.yml'] = (Marshal.dump(r=YAML.load(File.read('raspored.yml'))))
    options.R['rasapp:raspored.yml:ts']=Time.now.to_s
    # puts "Ras loadan iz filea"
  else
    r = Marshal.load x
    # puts "Ras loadan iz redisa"
  end
  r
end

def load_cal
  x, d = options.R['rasapp:cal'], options.R['rasapp:cal:ts']
  if x.nil? || x.empty? || (Time.parse(d.nil? ? "1.1.2000." : d) < File.mtime(CAL_URL[/file:\/\/(.+)/,1]))
    options.R['rasapp:cal'] = Marshal.dump(r=CalendarReader::Calendar.new(CAL_URL))
    options.R['rasapp:cal:ts']=Time.now.to_s
    # puts "Cal loadan iz filea"
  else
    r = Marshal.load x
    # puts "Cal loadan iz redisa"
  end
  r
end

def prvi_dan_tj
  DateTime.now - DateTime.now.strftime("%w").to_i
end

def wrap_text(txt, col = 80)
  txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n") 
end

def smjena(datum) # in: <Time>; out: 0 ili 1 (jut. ili pod.)
  d=DateTime.strptime(POC_DATUM[0], "%d.%m.%Y")
  r=((datum.strftime("%W").to_i - d.strftime("%W").to_i).abs + POC_DATUM[1])%2
  r=(r+1)%2 if DateTime.now.strftime("%w")=="0"
  r
end

def razredi(r=load_ras) # in: r; out: razredi
  r.first.collect{|t| t if t.string?}.compact
end

def raz(str) # in: razred_string; out: formatirani raz., npr.: {in: 2009_a; out: 2.a}
  d = DateTime.strptime("#{str[/\d+_/].to_i}/09", "%Y/%m")
  return false if d>DateTime.now
  "#{(1+((DateTime.now-d)/365).to_i)}.#{str[/_(.+)$/, 1]}"
end

def boja(s, i, p="") # dan, sat, txt
  # return "gray" if %w(uto sri).include?(s) && (2..4).include?(i)
  return "empty" if p =~ /--/
  return "wgray" if p =~ /SRO/ || p =~ /TZK/
  # return "blue"  if p =~ /INF/
  nil
end

def ras_html(tj, var=nil) #tj: [0:]
  @tj = tj
  @dani = %w(pon uto sri cet pet sub ned)

  @vars = @r['conf']['var'] rescue nil
  # @var = var if @var.nil?
  @var = var
  @var = @vars[0] rescue nil if @var.nil?
  varsw = @r['conf']['var_'+@var] rescue nil
  # puts "Dbg:\n@var: #{@var}\n@r: #{@r.inspect}\nvarsw: #{varsw.inspect}"

  @ras = {}
  @dani.first(5).each {|s|
    @ras[s] = @r[s].sort{|a,b| (smjena(DateTime.now)==0) ? (b[0]<=>a[0]) : (a[0]<=>b[0]) }.
    inject({}){|h, (k, v)| h[k]=(v.nil?) ? "--" : v.upcase; h}
    if !varsw.nil? && (xx=varsw.collect{|x| x if x=~/^#{s}_/}.compact)
      # [sri_7_inf2, cet_1_inf2]
      xx.each{|x|
        da, sa, pr, uc = x.split '_'
        # puts "BB #{da.inspect} #{sa.inspect} #{pr.inspect} #{uc.inspect} => #{pr}#{", "+uc if uc}"
        @ras[da][sa.to_i] = "#{pr}#{", "+uc if uc}".upcase
      }
    end
  }

  # x = options.R['rasapp:cal'].to_s
  # g = (!x.nil? && !x.empty?) ? Marshal.load(x) : (options.R['rasapp:cal']=Marshal.dump(x=CalendarReader::Calendar.new(CAL_URL)); x)
  @g ||= load_cal

  @eventi = {}; @dani.first(5).each {|x| @eventi[x]=[]}
  ((@g.past_events+@g.future_events).
  collect{|x|
    @eventi[@dani[x.start_time.strftime("%w").to_i-1]] <<
      [x.summary, x.description] if
        (x.start_time.to_datetime >= (prvi_dan_tj+7*@tj)) &&
        (x.start_time.to_datetime <= (prvi_dan_tj+5+7*@tj))
  })
  @dani.first(5).each{|d| @eventi[d].sort!}

  haml :ras_tbl, :layout => false
end

def get_ras_tj(raz, tj)
  @r = options.r[raz] rescue (return nil)
  ras = {}
  %w(pon uto sri cet pet).each {|s|
    ras[s] = @r[s].sort{|a,b| (smjena(DateTime.now+tj*7)==0) ? (b[0]<=>a[0]) : (a[0]<=>b[0]) }.
    inject({}){|h, (k, v)| h[k]=(v.nil?) ? "--" : v.upcase; h}
  }
  ras
end

def ozn?(predmet, eventi_d) # oznaci sat u danu ako je u eventima tog dana
  eventi_d.compact.each{|e|
    return true if !predmet.nil? &&
      (e[/(\w+) /,1].downcase rescue "") == predmet.downcase
  }
  false
end

def razd(l) # [1,2,3] -> [1, -1, 2, -1, 3]
  for i in 0..(l.count-1)
    l.insert 1+2*i, -1
  end
  l[0..(l.count-2)]
end

def ts(); @TIME_x = Time.now; end
def tg(txt=nil); puts "#{('T: '+txt+' > ' if !txt.nil?)}#{(Time.now-@TIME_x).to_f} seconds"; end
