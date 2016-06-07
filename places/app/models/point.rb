class Point
    attr_accessor :latitude, :longitude 
    
    def to_hash
        point = {}
        point[:type] = "Point"
        point[:coordinates] = [@longitude, @latitude]
        return point
    end
    
    def initialize(params)
        if params[:type] == "Point"
            @latitude = params[:coordinates][1]
            @longitude = params[:coordinates][0]
        else
            @latitude = params[:lat]                
            @longitude = params[:lng]
        end
    end
end