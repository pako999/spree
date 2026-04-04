sql = <<-SQL
  SELECT tablename, indexname, idx_scan
  FROM pg_stat_user_indexes
  WHERE idx_scan = 0
    AND schemaname = 'public'
    AND tablename LIKE 'spree_%'
  ORDER BY tablename, indexname
  LIMIT 40
SQL
rows = ActiveRecord::Base.connection.execute(sql)
rows.each { |r| puts "#{r['tablename'].ljust(45)} #{r['indexname']}" }

puts "\n--- Slow/sequential scan tables ---"
sql2 = <<-SQL
  SELECT relname, seq_scan, idx_scan,
         n_live_tup
  FROM pg_stat_user_tables
  WHERE relname LIKE 'spree_%'
    AND seq_scan > 100
  ORDER BY seq_scan DESC
  LIMIT 20
SQL
rows2 = ActiveRecord::Base.connection.execute(sql2)
rows2.each { |r| puts "seq=#{r['seq_scan'].to_s.rjust(8)} idx=#{r['idx_scan'].to_s.rjust(8)} rows=#{r['n_live_tup'].to_s.rjust(8)} #{r['relname']}" }
