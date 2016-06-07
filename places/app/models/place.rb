class Place
    attr_accessor :id, :formatted_address, :location, :address_components
    
    #Class Methods

    #Returns MongoDB Client
    def self.mongo_client
        Mongoid::Clients.default
    end
    
    #Returns Collection of Places in DB
    def self.collection
        mongo_client[:places]
    end
    
    #Loads collection using JSON file
    def self.load_all io
        contents = io.read
        contents = JSON.parse(contents)
        collection.insert_many(contents)
    end
    
    #Finds document if short name in address_components matches parameter
    def self.find_by_short_name param
        collection.find({"address_components.short_name":param}) 
    end
    
    #Returns a set  of Places generated using provided hash
    def self.to_places set
        results = []
        set.each do |r|
            results << Place.new(r)
        end
        return results
    end

    #Returns a Place given an id
    def self.find id
        bson_id = BSON::ObjectId.from_string(id.to_s)
        bson_data = collection.find("_id":bson_id).first
        result = nil
        if !bson_data.nil?
            result = Place.new(bson_data)
        end
        return result
    end

    #Returns all documents given an optional offset and limit
    def self.all(offset=0, limit=nil)
        result=[]
        set = collection.find().skip(offset)
        if !limit.nil?
            set = set.limit(limit) 
        end

        set.each do |r|
            result << Place.new(r)
        end
        return result
    end

    #returns a collection of hash documents with address_components and their associated _id, formatted_address and location properties.
    def self.get_address_components(sort=nil,offset=nil,limit=nil)
        pipeline = [];
        pipeline << {:$project=>{"_id"=>1, "address_components"=>1, "formatted_address"=>1, "geometry.geolocation"=>1}}
        pipeline << {:$unwind => "$address_components"}
        pipeline << {:$sort => sort} if !sort.nil?
        pipeline << {:$skip => offset} if !offset.nil?
        pipeline << {:$limit => limit} if !limit.nil?
        set = collection.find
                    .aggregate(pipeline)
    end

    #Returns all country names
    def self.get_country_names
        pipeline = []
        pipeline << {:$project=>{"address_components.long_name"=>1, "address_components.types"=>1}}
        pipeline << {:$unwind=>"$address_components"}
        pipeline << {:$match=>{"address_components.types":"country"}}
        pipeline << {:$group=>{:_id=>"$address_components.long_name"}}
        set = collection.find.aggregate(pipeline)
        
        result = []
        set.each do |r|
            result << r[:_id]
        end
        return result
    end

    #Returns ids of all docs that match a country code
    def self.find_ids_by_country_code country_code
        result = [];
        pipeline = []
        pipeline << {:$match=>{"address_components.short_name":country_code}}
        pipeline << {:$project=>{"_id"=>1}}
        set = collection.find.aggregate(pipeline)
        set.map{|r| result << r[:_id].to_s}
        return result
    end

    #Create Geolocation indexes
    def self.create_indexes
        collection.indexes.create_one({"geometry.geolocation" => Mongo::Index::GEO2DSPHERE})
    end

    #Remove Geolocation indexes
    def self.remove_indexes
        collection.indexes.drop_one({"geometry.geolocation" => Mongo::Index::GEO2DSPHERE})
    end

    #Returns places close to input place
    def self.near(point,max_meters=nil)
        pipeline = {}
        pipeline["$geometry"] = point.to_hash
        pipeline["$maxDistance"] = max_meters if !max_meters.nil?
        collection.find({
            "geometry.geolocation" => {
                :$near => pipeline
            }
        })
    end
####################################################################################################################################################
    
    #Instance Methods

    #Constructor
    def initialize(params)
        @id = params[:_id].to_s
        @formatted_address = params[:formatted_address]
        @location = Point.new(params[:geometry][:geolocation])
        @address_components = [] 
        params[:address_components].each do |address|
            address_component_temp = AddressComponent.new(address)
            @address_components << address_component_temp        
        end if !params[:address_components].nil?
    end

    #Deletes from database
    def destroy
        bson_id = BSON::ObjectId.from_string(id.to_s)
        Place.collection.delete_one(_id:bson_id)
    end

    #Returns places close to instance place
    def near(max_meters=nil)
        point = location.to_hash
        max_distance = max_meters
        set = Place.near(point, max_distance)
        Place.to_places(set)
    end
end