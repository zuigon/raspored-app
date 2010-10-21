require "rubygems"
require "time"

class Fixnum
  def minuta
    self*60
  end
  def sati
    self*60*60
  end
end

class Time
  def frm
    self.strftime("%H:%M")
  end
end

def sati()
  odmori = [5, 15 ,5, 10, 5, 5]
  bl = lambda {|start, smj|
    t=start=Time.parse(start); i=1; lasto=0
    puts; puts "Smjena #{smj}:"
    for o in odmori+[0]
      poc, kr = t, nil
      t+=45.minuta
      t-=5.minuta if smj==1 && t.frm=="13:00" # 7.h 1. smjene 40min
      kr = t
      puts "#{i}. #{poc.frm} - #{kr.frm}"
      t+=o.minuta; i+=1; lasto=o.minuta
    end
  }
  bl.call("7:00", 1); bl.call("13:00", 2)

  return nil
end

def koji_sat?(vrijeme)
  odmori = [5, 15 ,5, 10, 5, 5]
  bl = lambda {|start, smj|
    t=start=Time.parse(start); i=1; lasto=0
    for o in odmori+[0]
      poc, kr = t, nil
      t+=45.minuta
      t-=5.minuta if smj==1 && t.frm=="13:00" # 7.h 1. smjene 40min
      kr, sad = t, vrijeme
      return [smj, i] if poc-lasto<=sad && sad<kr
      t+=o.minuta; i+=1; lasto=o.minuta
    end
  }
  bl.call("7:00", 1); bl.call("13:00", 2)

  return nil
end

def kada_sat?(smjena, sat)
  odmori = [5, 15 ,5, 10, 5, 5]
  bl = lambda {|start, smj|
    t=start=Time.parse(start); i=1; lasto=0
    for o in odmori+[0]
      poc, kr = t, nil
      t+=45.minuta
      t-=5.minuta if smj==1 && t.frm=="13:00" # 7.h 1. smjene 40min
      kr = t
      return "#{poc.frm} - #{kr.frm}" if smjena==smj && i==sat
      t+=o.minuta; i+=1; lasto=o.minuta
    end
  }
  bl.call("7:00", 1); bl.call("13:00", 2)

  return nil
end
