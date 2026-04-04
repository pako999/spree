# frozen_string_literal: true
conn = ActiveRecord::Base.connection

puts "=== UNUSED INDEXES on spree_* tables ==="
unused = conn.select_all(<<~SQL)
  SELECT relname AS table_name, indexrelname AS index_name, idx_scan
  FROM pg_stat_user_indexes
  JOIN pg_index ON pg_index.indexrelid = pg_stat_user_indexes.indexrelid
  WHERE idx_scan = 0
    AND relname LIKE 'spree_%'
    AND NOT pg_index.indisprimary
  ORDER BY relname, indexrelname
SQL
unused.each { |r| puts "  #{r['table_name'].ljust(40)} #{r['index_name']}" }

puts "\n=== HIGH seq_scan tables (potential missing indexes) ==="
seqs = conn.select_all(<<~SQL)
  SELECT relname AS table_name, seq_scan, idx_scan, n_live_tup AS row_count
  FROM pg_stat_user_tables
  WHERE relname LIKE 'spree_%'
    AND seq_scan > 100
  ORDER BY seq_scan DESC
  LIMIT 20
SQL
seqs.each { |r| puts "  seq=#{r['seq_scan'].to_s.rjust(7)} idx=#{r['idx_scan'].to_s.rjust(7)} rows=#{r['row_count'].to_s.rjust(7)} #{r['table_name']}" }
