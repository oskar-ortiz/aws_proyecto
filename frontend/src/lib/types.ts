export type DashboardContext = {
  region: string;
  ses_sender: string;
  db_write_host: string;
  db_read_host: string;
  db_name: string;
  asg_min: number;
  asg_max: number;
  asg_desired: number;
};

export type EnrollmentRow = {
  id: number;
  student_name: string;
  student_email: string;
  course_code: string;
  status: string;
  created_at: string;
};

export type EnrollmentsResponse = {
  items: EnrollmentRow[];
  source: string;
};
