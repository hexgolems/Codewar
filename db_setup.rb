
require 'rubygems'
require 'ostruct'
require 'couchrest'
require 'json'

if ARGV.length==1
  cw_config=JSON.parse(File.read(ARGV[0]))
else
    cw_config={
      "_id"=> "config",
      "arena"=> {
        "max_program_length"=> 40,
        "max_player_threads"=> 64,
        "min_dist"=> 100,
        "num_cycles"=> 10000,
        "num_rounds"=> 50,
        "num_cells"=> 2400
        },
      "interpreter"=> {
        "num_threads"=> 2,
        "blacklist"=>[]
        },
      "output"=>{
        "file"=>"www/scores.html",
        "generate_every_update" => "false",
        "round_time" => 15.0
        }
      }
end

$config=OpenStruct.new
$config.db=CouchRest.database!("http://127.0.0.1:5984/codewars")
begin
$config.db.delete!
$config.db=CouchRest.database!("http://127.0.0.1:5984/codewars")
rescue
end

  begin
  if res=$config.db.get("_design/codewars")
    $config.db.delete_doc(res)
  end
  rescue
  end

  $config.db.save_doc(cw_config)

    $config.db.save_doc({
      "_id" => "_design/codewars",
      :views => {
        :scores=>{
          :map => %{
          function(doc){
            if (doc.scores){
            for(var w in doc.scores){
                emit([doc._id,w],doc.scores[w])
            }
            }
          }
          }
        },
    :active_bots=>{
      :map => %{
          function(doc){
            if(doc.code){
            emit([doc.group,doc._id],{"_id":doc._id,"timestamp":doc.timestamp})
            }
          }
          },

      :reduce=>%{
        function(key,values,rereduce){
          var max_timestamp=0
          var retval=0
          for(var v in values){
            if(values[v].timestamp>max_timestamp){
              max_timestamp=values[v].timestamp
              max_id={"_id":values[v]._id,"timestamp":values[v].timestamp}
            }
          }

          return(max_id);
        }
        }
        },
    :highscores=>{
      :map=>%{
          function(doc){
            if (doc.scores){
              var sum=0
              for(var other in doc.scores){
                sum+=3*doc.scores[other]["wins"]+doc.scores[other]["ties"]
              }
              emit(sum,doc._id)
            }
          }
          }

      }
    }#end views
      })


