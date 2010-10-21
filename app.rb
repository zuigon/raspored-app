require "rubygems"
require "sinatra"
require "yaml"
require "gcal-lib"
require "sati-lib"
require "time"

POC_DATUM = ["6.9.2010", 0]
CAL_URL = "file://./basic.ics"
#http://www.google.com/calendar/ical/81d23ab0r2mcll612eeqlgtd90@group.calendar.google.com/public/basic.ics

# prvi_dan_tjedna(dan): x=(dan); x.strftime("%d.%m.%Y ")+(x-x.strftime("%w").to_i).strftime("%d.%m.%Y")
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

def razredi(r=options.r) # in: r; out: razredi
  r.first.collect{|t| t if t.class == String}.compact
end

def raz(str) # in: razred_string; out: formatirani raz., npr.: {in: 2009_a; out: 2.a}
  d = DateTime.strptime("#{str[/\d+_/].to_i}/09", "%Y/%m")
  return false if d>DateTime.now
  "#{(1+((DateTime.now-d)/365).to_i)}.#{str[/_(.+)$/, 1]}"
end

def boja(s, i, p="")
  # return "gray" if %w(uto sri).include?(s) && (2..4).include?(i)
  return "empty" if p =~ /--/
  return "wgray" if p =~ /SRO/
  return "wgray" if p =~ /TZK/
  return "blue"  if p =~ /INF/
  nil
end

configure do
  set :r, (YAML.load File.read 'raspored.yml')
end

get '/' do
  # @r = options.r
  haml :razredi
end

get '/raz/:str' do |str|
  @t_nast = ": #{raz str}"
  @str = str
  @r = options.r[str] rescue nil
  @ras, @rasNext = {}, {}
  %w(pon uto sri cet pet).each {|s|
    @ras[s] = @r[s].sort{|a,b| (smjena(DateTime.now)==0) ? (b[0]<=>a[0]) : (a[0]<=>b[0]) }.
    inject({}){|h, (k, v)| h[k]=(v.nil?) ? "--" : v.upcase; h}
    @rasNext[s] = @r[s].sort{|a,b| (smjena(DateTime.now)!=0) ? (b[0]<=>a[0]) : (a[0]<=>b[0]) }.
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

__END__

@@razredi
%h2 Svi razredi:
%ul
  - for r in razredi.sort
    %li
      %a{:href=>"/raz/#{r}"}= "#{raz r} (#{r})"

@@test
%pre= wrap_text(razredi(@r).inspect)
%h1 Raspored

@@razred
%h1= "Razred: #{raz @str}"

%h2= "Ovaj tjedan - #{(smjena DateTime.now)==0 ? "Prva" : "Druga"} smjena (#{(prvi_dan_tj+1).strftime "%d.%m."} - #{(prvi_dan_tj+5).strftime "%d.%m."})"

%table{:border=>2, :id=>"tbl_ras"}
  - @dani = %w(pon uto sri cet pet sub ned)
  - g = CalendarReader::Calendar.new(CAL_URL)
  %tr
    / @dani
    %th{:width=>20} &nbsp;
    - for s in @dani.first(5).map{|x| x.capitalize}
      %th{:width=>80, :class=>"gray#{(@dani[(DateTime.now.strftime("%w").to_i+6)%7] == s.downcase) ? " uline" : ""}"}= "#{s}"
  %tr
    / datumi
    %th &nbsp;
    - for i in 1..5
      %th= "#{(prvi_dan_tj+i).strftime "%d.%m."}"
  %tr
    / GCal eventi
    %th Kal.
    - for i in 1..5
      %th{:valign=>"top", :class=>"events_l"}
        %ul
          - for x in ((g.past_events+g.future_events).collect{|x| [x.summary, x.description] if (x.start_time.strftime("%d.%m.%Y")==(prvi_dan_tj+i).strftime("%d.%m.%Y"))}.compact)
            - hd = (!x[1].nil? && !x[1].empty?)
            %li{:class=>"gcal_event_li#{hd ? " hasdesc" : ""}", :title=>(hd ? x[1].split("\n").join("; ") : nil)}= "#{hd ? "+" : "-"} #{x.first}"
  - for i in 0..8
    %tr
      %td{:class=>"gray"}= "#{i}."
      - for s in @dani.first(5)
        - idx = (smjena(DateTime.now)==0) ? i : 8-i
        - t = (koji_sat?(Time.now) || [0, 0])
        - sada=nil; sada = (t[1] rescue nil) if @dani[(DateTime.now.strftime("%w").to_i-1)%7] == s && t[0]==(smjena(DateTime.now)+1)
        %td{:class=>"#{"tek_sat " if sada==i}#{boja(s, i, @ras[s][idx])}#{(@dani[(DateTime.now.strftime("%w").to_i-1)%7] == s) ? " danas" : ""}"}= (@ras[s][idx] =~ /\, /) ? "#{@ras[s][idx].gsub(/\, /, ' (')})" : @ras[s][idx] if !@ras[s][idx].nil?

%h2= "Slijedeci tjedan - #{(smjena DateTime.now+7)==0 ? "Prva" : "Druga"} smjena (#{(prvi_dan_tj+8).strftime "%d.%m."} - #{(prvi_dan_tj+12).strftime "%d.%m."})"

%table{:border=>2, :id=>"tbl_ras"}
  - @dani = %w(pon uto sri cet pet sub ned)
  - g = CalendarReader::Calendar.new(CAL_URL)
  %tr
    / @dani
    %th{:width=>20} &nbsp;
    - for s in @dani.first(5).map{|x| x.capitalize}
      %th{:width=>80, :class=>"gray"}= "#{s}"
  %tr
    / datumi
    %th &nbsp;
    - for i in 1..5
      %th= "#{(prvi_dan_tj+i+7).strftime "%d.%m."}"
  %tr
    / GCal eventi
    %th Kal.
    - for i in 1..5
      %th{:valign=>"top", :class=>"events_l"}
        %ul
          - for x in ((g.past_events+g.future_events).collect{|x| [x.summary, x.description] if (x.start_time.strftime("%d.%m.%Y")==(prvi_dan_tj+i+7).strftime("%d.%m.%Y"))}.compact)
            - hd = (!x[1].nil? && !x[1].empty?)
            %li{:class=>"gcal_event_li#{hd ? " hasdesc" : ""}", :title=>(hd ? x[1].split("\n").join("; ") : nil)}= "#{hd ? "+" : "-"} #{x.first}"
  - for i in 0..8
    %tr
      %td{:class=>"gray"}= "#{i}."
      - for s in @dani.first(5)
        - idx = (smjena(DateTime.now+7)==0) ? i : 8-i
        - x = @rasNext[s][idx]
        %td{:class=>"#{boja(s, i, x)}"}= (x =~ /\, /) ? "#{x.gsub(/\, /, ' (')})" : x if !x.nil?

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
    %title= (@title || "Raspored#{@t_nast}")
    %link{:href => "/style.css", :rel => "stylesheet", :type => "text/css"}/
    / %script{:src => "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", :type => "text/javascript"}
    / %script{:src => "http://plugins.jquery.com/files/jquery.cookie.js.txt", :type => "text/javascript"}
    / %script{:src => "/js/main.js", :type => "text/javascript"}
  %body
    %div{:align => "center"}
      %div{:align => "left"}
        = yield

