let chai = require('chai');
let chaiHttp = require('chai-http');
let server = require('../server');

// Assertion
let should = chai.should();
chai.use(chaiHttp);

describe('API Tests', () => {
    describe('Test POST to /manage_file when action is "read" ', () => {
        it('it should read content of file when action is "read"', (done) => {
            let read = {
                "action": "read"
            }
          chai.request(server)
              .post('/manage_file')
              .send(read)
              .end((err, res) => {
                    res.should.have.status(200);
                    res.header.should.have.property('content-type').contain('text/html');
                    res.header.should.have.property('content-length').equal('448');
                    should.not.exist(err);
                done();
              });
        });        
    });
    describe('Test POST to /manage_file when action is "download" ', () => {
        it('it should read content of file when action is "read"', (done) => {
            let download = {
                "action": "download"
            }
          chai.request(server)
              .post('/manage_file')
              .send(download)
              .end((err, res) => {
                    res.should.have.status(200);
                    res.header.should.have.property('content-disposition').equal('attachment; filename="sample-text-file.txt"');
                    res.header.should.have.property('content-length').equal('448');
                    should.not.exist(err);
                done();
              });
        });
    });
    describe('Test POST to /manage_file when no action is found" ', () => {
        it('it should respond with a message when no action is found ', (done) => {
            let message = "##Invalid Request (No valid value for key 'action' found in request)##";
            let noaction = {
                "something": "else"
            }
          chai.request(server)
              .post('/manage_file')
              .send(noaction)
              .end((err, res) => {
                    res.should.have.status(400);
                    res.body.should.have.property('message').equal(message);
                    should.not.exist(err);
                done();
              });
        });
    });        

});