require "rubygems"
require "sinatra"
require "yaml"

POC_DATUM = ["6.9.2010", 0]

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
  d = DateTime.strptime("#{str[/\d+_/].collect{|g| g.to_i}.first}/09", "%Y/%m")
  return false if d>DateTime.now
  "#{(1+((DateTime.now-d)/365).to_i)}.#{str[/_(.+)$/, 1]}"
end

def boja(s, i, p="")
  # return "gray" if %w(uto sri).include?(s) && (2..4).include?(i)
  return "empty" if p =~ /--/
  return "wgray" if p =~ /SRO/
  return "wgray" if p =~ /TZK/
  return "blue" if p =~ /INF/
  ""
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

%table{:border=>1, :style=>"text-align: center;"}
  %tr
    %th{:width=>20} &nbsp;
    - for s in %w(Pon Uto Sri Cet Pet)
      %th{:width=>75, :class=>"gray"}= s
  - for i in 0..8
    %tr
      %td{:class=>"gray"}= "#{i}."
      - for s in %w(pon uto sri cet pet)
        - idx = (smjena(DateTime.now)==0) ? i : 8-i
        %td{:class=>boja(s, i, @ras[s][idx])}= @ras[s][idx].collect{|h| h="#{h.gsub(/\, /, ' (')})" if h =~ /\, /; h} if !@ras[s][idx].nil?

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

