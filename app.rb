require "rubygems"
require "sinatra"
require "yaml"
require "time"
require "redis"
require "gcal-lib"
require "sati-lib"
require "app-lib"

POC_DATUM = ["6.9.2010", 0]
CAL_URL = "file://./basic.ics"
DEF_GEN = "2009" # default razredi
DOM = "http://raspored.bkrsta.co.cc"
#http://www.google.com/calendar/ical/81d23ab0r2mcll612eeqlgtd90@group.calendar.google.com/public/basic.ics

configure do
  set :R, Redis.new
  # set :r, load_ras()
  set :r, nil
  error 404 do
    haml "%h1.err Grijeska cetiri nula cetiri ..."
  end
  error 500 do
    haml "%h1.err ... excuse me while I kiss the sky! (Greska)\n%h2.err greska se dogodila sada da se ne bi dogodila kasnije"
  end
end

before do
  redirect DOM+env["REQUEST_URI"] if env["SERVER_NAME"] == "bkrsta.co.cc"
end

get '/' do
  # @r = options.r
  @razredi = razredi.sort
  # razd @razredi
  # @razredi = @razredi.delete_at -1 if @razredi[-1] == -1
  haml :razredi
end

get '/raz/:x' do |x|
  if x =~ /^2009_/
    redirect "/#{x[/2009_(.+)/,1]}"
  else
    redirect "/#{x}"
  end
end

# /a ili /2009_a
[%r{^/([a-z])\/?$}, %r{^/([\d]{2}?\d\d_[a-z])\/?$}].each do |path|
  get path do |str|
    @dani = %w(pon uto sri cet pet sub ned)
    str = "#{DEF_GEN}_#{str}" if str =~ /^[a-z]$/
    str = "20#{str}" if str =~ /^\d\d_[a-z]$/
    (error 404; return) if ! str =~ /^\d\d\d\d_[a-z]$/
    options.r = load_ras() if options.r.nil? # ako ga GC pojede
    (error 404; return) if ! options.r[str]
    @str = str; @t_nast = ": #{raz str}"
    @r = options.r[str] rescue nil

    if params['v']
      @var = params['v']
      response.set_cookie "#{@str}_var", @var
    else
      @var=request.cookies["#{@str}_var"]
    end
    @vars = @r['conf']['var'] rescue nil
    @var=nil if @var =~ /[^a-z0-9]/i
    (@var=@vars[0] rescue nil) if @var.nil? # default varijanta

    haml :razred
  end
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

__END__

@@ras_tbl
- if @tj == 0
  - str = "Ovaj tjedan "
- elsif @tj == 1
  - str = "Slijedeci tjedan "
- else
  - str = ""
%h2= "#{str} (#{(smjena DateTime.now+@tj*7)==0 ? "1." : "2."} smjena)"

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

@@razredi
%center
  %table#t
    %tr
      %td
        %div#fl_d
          %h1.raz_naslov R
      %td
        %ul.svi_razredi
          - for r in @razredi
            %li
              %a{:href=>"/#{r}"}= raz r

@@test
%pre= wrap_text(razredi(@r).inspect)
%h1 Raspored

@@razred
%h1= "Razred: #{raz @str}"

/ %select{:name=>"varijanta", :onchange=>"alert(this.options[this.selectedIndex].value);"}
/   - for v in @vars
/     %option{:selected=>(v==var)?true:nil}= v.upcase

%span{:style=>"font-size: 1.3em; font-weight: bold; margin-right: 10px;"} Varijante:
%span#varijante
  - for v in @vars
    %a{:selected=>(v==@var)?'1':nil, :href=>"?v=#{v}"}= v.upcase

%div#rasporedi
  %div#tj0= ras_html(0, @var)
  %div#tj1= ras_html(1, @var)

/ %a{:href=>"#", :onclick=>"$('div#rasporedi').load('/ras/#{@str}/tj/2');"} Jos tjedana

%div.cb

%p
  %a{:href=>"/raz/#{@str}/prijedlog"} Prijedlog novog eventa
  &nbsp; | &nbsp;
  %a{:href=>"/"} Svi razredi
%p
  %a{:href=>"http://github.com/bkrsta/raspored-app"} Source

@@prijedlog
%h1= @title
form{:action=>"/raz/#{@str}/prijedlog", :method=>"post"}
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
      = '$(function(){$("table#tbl_ras tr td, table#tbl_ras th.events_l").hover(function(){$(this).addClass("highlight");},function(){$(this).removeClass("highlight");})})'
  %body
    %div{:id=>"container"}
      - if (!!(request.referer.match(/http:\/\/raz(red)?.bkrsta.co.cc\/.+/)[0] rescue false))
        %a{:href=>request.referer, :style=>"color: red;"} &lt;&lt; Nazad na forum
      - else
        %a{:href=>"http://razred.bkrsta.co.cc/", :style=>"color: red;"} Forum

      = yield

