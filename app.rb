require "rubygems"
require "sinatra"
require "yaml"
require "gcal-lib"
require "sati-lib"
require "time"
require "redis"

POC_DATUM = ["6.9.2010", 0]
CAL_URL = "file://./basic.ics"
#http://www.google.com/calendar/ical/81d23ab0r2mcll612eeqlgtd90@group.calendar.google.com/public/basic.ics

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
  if x.nil? || (Time.parse(d.nil? ? "1.1.2000." : d) < File.mtime('raspored.yml'))
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
  if x.nil? || (Time.parse(d.nil? ? "1.1.2000." : d) < File.mtime(CAL_URL[/file:\/\/(.+)/,1]))
    options.R['rasapp:cal']= (options.R['rasapp:cal']=Marshal.dump(r=CalendarReader::Calendar.new(CAL_URL)))
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

def ras_html(tj) #tj: [0:]
  @tj = tj
  @dani = %w(pon uto sri cet pet sub ned)

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

configure do
  set :R, Redis.new
  # set :r, load_ras()
  set :r, nil
  error 404 do
    haml "%h1.err Grijeska cetiri nula cetiri ..."
  end
  error 500 do
    haml "%h1.err ... excuse me while I kiss the sky! (Pardon 500)"
  end
end

def ts
  @TIME_x = Time.now
end

def tg(txt=nil)
  puts "#{('T: '+txt+' > ' if !txt.nil?)}#{(Time.now-@TIME_x).to_f} seconds"
end

get '/' do
  # @r = options.r
  # @razredi = (razredi+%w(2009_b 2009_c 2009_d)).sort
  @razredi = razredi.sort
  # razd @razredi
  # @razredi = @razredi.delete_at -1 if @razredi[-1] == -1
  haml :razredi
end

get '/raz/:str' do |str|
  (error 404; return) if ! str =~ /^\d\d\d\d_[a-z]$/
  options.r = load_ras() if options.r.nil? # ako ga GC pojede
  (error 404; return) if ! options.r[str]
  @t_nast = ": #{raz str}"
  @str = str
  @r = options.r[str] rescue nil
  @ras, @rasNext = {}, {}
  %w(pon uto sri cet pet).each {|s|
    @ras[s] = @r[s].sort{|a,b| (smjena(DateTime.now)==0) ? (b[0]<=>a[0]) : (a[0]<=>b[0]) }.
    inject({}){|h, (k, v)| h[k]=(v.nil?) ? "--" : v.upcase; h}
  }
  haml :razred
end

get '/raz/:str/prijedlog' do |str|
  error 404 if ! str =~ /^\d\d\d\d_\d+$/
  @str = str
  @title = "Prijedlog novog eventa"

  haml :prijedlog
end

post '/raz/:str/prijedlog' do |str|
  error 404 if ! str =~ /^\d\d\d\d_\d+$/
  datum, naziv, opis = params[:date], params[:naziv], params[:opis]
  open('prijedlozi.txt', 'a'){ |f|
    f.puts "======================"
    f.puts "Vrijeme: #{Time.now.strftime "%d.%m.%Y %H:%M"}"
    f.puts "Remote addr.: #{@env['REMOTE_ADDR']}"
    f.puts "@ RAZRED: #{str} (#{raz str})"
    f.puts "@ Datum: #{datum}"
    f.puts "@ Naziv: #{naziv}"
    f.puts "@ Opis:  #{opis.inspect}"
    f.puts "======================"
  }
  redirect "/raz/#{str}"
end

get '/rr' do
  out = `./get-cal.sh`
  "<pre>#{out}</pre>"
end

get '/raz/:str/tj/:tj' do |str, tj|
  error 404 if ! str =~ /^\d\d\d\d_\d+$/
  error 404 if ! tj =~ /\d+/ && tj.to_i >= 0 && tj.to_i <= 50
  @tj = tj.to_i
  @ras = get_ras_tj(str, @tj)
  haml :ras_tbl, :layout => false
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

__END__

@@ras_tbl
- if @tj == 0
  - str = "Ovaj tjedan - "
- elsif @tj == 1
  - str = "Slijedeci tjedan - "
- else
  - str = ""
%h2= "#{str} (#{(smjena DateTime.now+@tj*7)==0 ? "1." : "2."} smjena, #{(prvi_dan_tj+@tj*7+1).strftime "%d.%m."} - #{(prvi_dan_tj+@tj*7+5).strftime "%d.%m."})"

%table{:border=>2, :id=>"tbl_ras"}
  %tr
    / dani
    %th{:width=>20} &nbsp;
    - for s in @dani.first(5).map{|x| x.capitalize}
      %th{:width=>80, :class=>"gray#{(@dani[(DateTime.now.strftime("%w").to_i+6)%7] == s.downcase) ? " uline" : "" if @tj==0}"}= "#{s}"
  %tr
    / datumi
    %th &nbsp;
    - for i in 1..5
      %th= "#{(prvi_dan_tj+i+@tj*7).strftime "%d.%m."}"
  %tr
    / GCal eventi
    %th Kal.
    - for i in 1..5
      %th{:valign=>"top", :class=>"events_l"}
        %ul
          - for x in @eventi[@dani[i-1]]
            - hd = (!x[1].nil? && !x[1].empty?)
            %li{:class=>"gcal_event_li#{hd ? " hasdesc" : ""}", :title=>(hd ? x[1].split("\n").join("; ") : nil)}= "#{hd ? "+" : "-"} #{x.first}"
  - for i in 0..8
    %tr
      %td{:class=>"gray"}= "#{i}."
      - for s in @dani.first(5)
        - idx = (smjena(DateTime.now+@tj*7)==0) ? i : 8-i
        - x = @ras[s][idx]
        - klase = []
        - klase << boja(s, i, x)
        - klase << "ozn" if !x.nil? && ozn?(x[/(\w+)/,1], @eventi[s].collect{|e| e[0]})
        - if @tj == 0
          - t = (koji_sat?(Time.now) || [0, 0])
          - sada=nil; sada = (t[1] rescue nil) if @dani[(DateTime.now.strftime("%w").to_i-1)%7] == s && t[0]==(smjena(DateTime.now)+1)
          - klase << "tek_sat" if sada==i
          - klase << ((@dani[(DateTime.now.strftime("%w").to_i-1)%7] == s) ? "danas" : "")
          %td{:class=>klase.join(' ')}= (x =~ /\, /) ? "#{x.gsub(/\, /, ' (')})" : x if !x.nil?
        - else
          %td{:class=>klase.join(' ')}= (x =~ /\, /) ? "#{x.gsub(/\, /, ' (')})" : x if !x.nil?

@@razredi
%center
  %div#fl_d
    %h1.raz_naslov R
  %ul.svi_razredi
    - for r in @razredi
      %li
        %a{:href=>"/raz/#{r}"}= raz r

@@test
%pre= wrap_text(razredi(@r).inspect)
%h1 Raspored

@@razred
%h1= "Razred: #{raz @str}"

%div#rasporedi
  %div#tj0= ras_html(0)
  %div#tj1= ras_html(1)

/ %a{:href=>"#", :onclick=>"$('div#rasporedi').load('/ras/#{@str}/tj/2');"} Jos tjedana

%p
  %a{:href=>"/raz/#{@str}/prijedlog"} Prijedlog novog eventa
  &nbsp; | &nbsp;
  %a{:href=>"/"} Svi razredi
%p
  %a{:href=>"http://github.com/bkrsta/raspored-app"} Source

@@prijedlog
%h1= @title
%form{:action=>"/raz/#{@str}/prijedlog", :method=>"post"}
  %p
    %label{:for=>"date"} Datum
    %br
    %input{:type=>"text", :name=>"date", :size=>12}
    %span.help D.M.GGGG.
  %p
    %label{:for=>"naziv"} Naziv
    %br
    %input{:type=>"text", :name=>"naziv"}
    %span.help npr.: HJ test
  %p
    %label{:for=>"opis"} Opis
    %br
    %textarea{:name=>"opis", :rows=>5, :cols=>30}
  %p
    %input{:type=>"submit", :value=>"Salji"}

@@layout
!!! Transitional
%html{:xmlns => "http://www.w3.org/1999/xhtml"}
  %head
    %meta{:content => "text/html; charset=iso-8859-1", "http-equiv" => "Content-Type"}/
    %title= (@title || "Raspored#{@t_nast || "App"}")
    %link{:href => "/style.css", :rel => "stylesheet", :type => "text/css"}/
    %script{:src => "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", :type => "text/javascript"}
    / %script{:src => "http://plugins.jquery.com/files/jquery.cookie.js.txt", :type => "text/javascript"}
    / %script{:src => "/js/main.js", :type => "text/javascript"}
    / %script{:type => "text/javascript"}
    / = "function getras(var n){$.get(\"/ras/\"+tj+\"/tj/2\");\",function(data){$(\"#rasporedi\").append(data));});} }"
    %script{:type => "text/javascript"}
      = '$(function(){$("td, th.events_l").hover(function(){$(this).addClass("highlight");},function(){$(this).removeClass("highlight");})})'
  %body
    %div{:id=>"container"}
      = yield

