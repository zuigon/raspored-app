require "rubygems"
require "sinatra"
require "yaml"
require "gcal-lib"

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
  @ras = {}
  %w(pon uto sri cet pet).each {|s|
    @ras[s] = @r[s].sort{|a,b| (smjena(DateTime.now)==0) ? (b[0]<=>a[0]) : (a[0]<=>b[0]) }.
    inject({}){|h, (k, v)| h[k]=(v.nil?) ? "--" : v.upcase; h}
  }
  haml :razred
end

__END__

@@razredi
%h2 Svi razredi:
%ul
  - for r in razredi
    %li
      %a{:href=>"/raz/#{r}"}= "#{raz r} (#{r})"

@@root
%pre= wrap_text(razredi(@r).inspect)
%h1 Raspored

@@razred
%h1= "Razred: #{raz @str}"

- if (smjena DateTime.now) == 0
  %h2 Jutarnja smjena
- elsif (smjena DateTime.now )== 1
  %h2 Popodnevna smjena

%table{:border=>2, :id=>"tbl_ras"}
  - @dani = %w(pon uto sri cet pet sub ned)
  - g = CalendarReader::Calendar.new(CAL_URL)
  %tr
    / @dani
    %th{:width=>20} &nbsp;
    - for s in @dani.first(5).map{|x| x.capitalize}
      %th{:width=>80, :class=>"gray#{(@dani[(((DateTime.now).strftime "%w").to_i+6)%7] == s.downcase) ? " uline" : ""}"}= "#{s}"
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
            %li{:class=>"gcal_event_li#{!x[1].nil? && !x[1].empty? ? " hasdesc" : ""}", :title=>(!x[1].nil? && !x[1].empty? ? x[1] : nil)}= "- #{x.first}"

  - for i in 0..8
    %tr
      %td{:class=>"gray"}= "#{i}."
      - for s in @dani.first(5)
        - idx = (smjena(DateTime.now)==0) ? i : 8-i
        %td{:class=>boja(s, i, @ras[s][idx])}= (@ras[s][idx] =~ /\, /) ? "#{@ras[s][idx].gsub(/\, /, ' (')})" : @ras[s][idx] if !@ras[s][idx].nil?


@@layout
!!! Transitional
%html{:xmlns => "http://www.w3.org/1999/xhtml"}
  %head
    %meta{:content => "text/html; charset=iso-8859-1", "http-equiv" => "Content-Type"}/
    %title= "Raspored#{@t_nast}"
    %link{:href => "/style.css", :rel => "stylesheet", :type => "text/css"}/
    / %script{:src => "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", :type => "text/javascript"}
    / %script{:src => "http://plugins.jquery.com/files/jquery.cookie.js.txt", :type => "text/javascript"}
    / %script{:src => "/js/main.js", :type => "text/javascript"}
  %body
    %div{:align => "center"}
      %div{:align => "left"}
        = yield

