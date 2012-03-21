module QualityCenter
  module RemoteInterface

    class Rest
      AUTHURI  = {
        get:  '/qcbin/authentication-point/login.jsp',
        post: '/qcbin/authentication-point/j_spring_security_check'
      }
      PREFIX  = '/qcbin/rest'
      DEFECTS = '/domains/TEST/projects/AssessmentQualityGroup/defects'
    end

    class Query
      DIRECTIONS = %w[ASC DESC]
      DEFAULT = {
        paging: { limit: 10,   offset: 0 },
        order:  { field: 'id', direction: 'DESC' }
      }
    end

  end
end
