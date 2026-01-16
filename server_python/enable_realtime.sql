-- Enable Realtime for Orders and Deliveries
begin;
  -- Check if publication exists, usually strict supabase_realtime
  alter publication supabase_realtime add table orders;
  alter publication supabase_realtime add table deliveries;
commit;
