class Photo
    attr_accessor :id, :location
    attr_writer :contents

    def self.mongo_client
        Mongoid::Clients.default
    end

    def self.all(skip=0, limit=nil)
        result = mongo_client.database.fs.find.skip(skip)
        result = result.limit(limit) if !limit.nil?
        result.map{|doc| Photo.new(doc)}
    end

    def self.find id
        bson_id = BSON::ObjectId.from_string(id.to_s)
        set = mongo_client.database.fs.find(:_id=>bson_id).first
        result = Photo.new(set)
        return result
    end
    def initialize(params=nil)
        if !params.nil?
            @id = params[:_id].to_s if !params[:_id].nil?
            @location = Point.new(params[:metadata][:location]) if !params[:metadata][:location].nil?
        end
    end


    def persisted?
        !@id.nil?
    end

    def save
        if !persisted?
            gps=EXIFR::JPEG.new(@contents).gps
            @location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)

            description = {}
            description[:metadata] = {}
            description[:metadata][:location] = @location.to_hash
            description[:content_type] = "image/jpeg"
            
            @contents.rewind
            grid_file = Mongo::Grid::File.new(@contents.read, description)
            @id = Photo.mongo_client.database.fs.insert_one(grid_file).to_s
        end
        return id
    end
end