module DocumentGenerator
  module JsonApiHelpers
    def find_included_record_by_type data, type
      if data['included']
        data['included'].find { |r| r['type'] == type }
      else
        nil
      end
    end

    def find_included_record_by_id data, id
      if data['included']
        data['included'].find { |r| r['id'] == id }
      else
        nil
      end
    end

    def find_related_record record, data, relation
      if record and record['relationships'] and record ['relationships'][relation]
        related_id = record['relationships'][relation]['data']['id']
        find_included_record_by_id data, related_id
      else
        nil
      end
    end

    def find_related_records record, data, relation
      if record and record['relationships'] and record ['relationships'][relation]
        related_ids = record['relationships'][relation]['data'].select { |r| r['id'] }
        related_ids.select { |id| find_included_record_by_id(data, id) }
      else
        []
      end
    end
  end
end
