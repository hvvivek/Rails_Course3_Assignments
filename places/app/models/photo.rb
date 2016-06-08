class Photo
    attr_accessor :id, :location, :place
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
        result = nil
        bson_id = BSON::ObjectId.from_string(id.to_s)
        set = mongo_client.database.fs.find(:_id=>bson_id).first
        result = Photo.new(set) if !set.nil? 
        return result
    end

    def self.find_photos_for_place id
        id = BSON::ObjectId.from_string(id.to_s)
        grid_file = mongo_client.database.fs.find("metadata.place"=>id)
    end

    def initialize(params=nil)
        if !params.nil?
            @id = params[:_id].to_s if !params[:_id].nil?
            @location = Point.new(params[:metadata][:location]) if !params[:metadata][:location].nil?
            @place = params[:metadata][:place] if !params[:metadata][:place].nil?
        end
    end


    def persisted?
        !@id.nil?
    end

    def find_nearest_place_id max_meters
        result = Place.near(@location.to_hash, max_meters).limit(1).projection(:_id=>1).first[:_id]
        result || 0
    end

    def save
        if !persisted?
            gps=EXIFR::JPEG.new(@contents).gps
            @location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)

            description = {}
            description[:metadata] = {}
            description[:metadata][:location] = @location.to_hash
            description[:metadata][:place] = @place
            description[:content_type] = "image/jpeg"
            
            @contents.rewind
            grid_file = Mongo::Grid::File.new(@contents.read, description)
            @id = Photo.mongo_client.database.fs.insert_one(grid_file).to_s
        else 
            grid_file = Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id.to_s)).update_one(:$set => {"metadata.location" => @location.to_hash})
            grid_file = Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id.to_s)).update_one(:$set => {"metadata.place" => @place})
        end
        return @id
    end

    def contents
        bson_id = BSON::ObjectId.from_string(@id.to_s)
        @contents = ""
        stored_file = Photo.mongo_client.database.fs.find_one(:_id=>bson_id)
        stored_file.chunks.reduce([]){|x,chunk| @contents << chunk.data.data}
        return @contents        
    end

    def destroy
        bson_id = BSON::ObjectId.from_string(@id.to_s)
        Photo.mongo_client.database.fs.delete(bson_id)
    end

    def place
        result = nil
        result = Place.find(@place.to_s) if !@place.nil?
        return result
    end

    def place=param
       result = BSON::ObjectId.from_string(param) if param.is_a?(String)
       result = param if param.is_a?(BSON::ObjectId)
       result = BSON::ObjectId.from_string(param.id.to_s) if param.is_a?(Place)
       #grid_file = Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id.to_s)).update_one(:$set => {"metadata.place" => result})
       @place = result
    end
end