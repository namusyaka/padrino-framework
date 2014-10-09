
class RackApp
  def self.call(_)
    [200, {}, ["hello rack app"]]
  end
end

RackApp2 = lambda{|_| [200, {}, ["hello rack app2"]] }

class SinatraApp < Sinatra::Base
  get "/" do
    "hello sinatra app"
  end
end
