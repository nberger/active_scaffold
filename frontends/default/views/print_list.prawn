  # pdf.text active_scaffold_config.print_list.header_text if active_scaffold_config.print_list.header_text
  headers = active_scaffold_tools_list_columns.collect {|column| column.label}
  rows = []
  @records.each do |record|
    columns = []
    active_scaffold_tools_list_columns.each do |column|
      save_column_inplace_edit = column.inplace_edit
      column.inplace_edit = false
      column.list_ui = :boolean if column.list_ui and column.list_ui.to_sym == :checkbox
      columns << get_column_value(record, column).gsub('&nbsp;', '').gsub('&amp;', '&')
      column.inplace_edit = save_column_inplace_edit
    end
    rows << columns
  end

  pdf.font "#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf"
  pdf.table rows,
    :font_size  => active_scaffold_config.print_list.font_size, 
    :horizontal_padding => 10,
    :vertical_padding   => 3,
    :border_width       => 1,
    :position           => :left,
    :headers            => headers,
    :align              => {1 => :center},
    :align_headers      => :center,
    :row_colors         => :pdf_writer